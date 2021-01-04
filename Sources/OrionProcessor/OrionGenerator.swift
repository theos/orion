import Foundation
import SwiftSyntax

private extension Sequence {
    // y u no variadic generics, swift :/

    func unzip<T1, T2>() -> ([T1], [T2]) where Element == (T1, T2) {
        reduce(into: ([] as [T1], [] as [T2])) { arrays, element in
            arrays.0.append(element.0)
            arrays.1.append(element.1)
        }
    }

    func unzip<T1, T2, T3>() -> ([T1], [T2], [T3]) where Element == (T1, T2, T3) {
        reduce(into: ([] as [T1], [] as [T2], [] as [T3])) { arrays, element in
            arrays.0.append(element.0)
            arrays.1.append(element.1)
            arrays.2.append(element.2)
        }
    }

    func unzip<T1, T2, T3, T4>() -> ([T1], [T2], [T3], [T4]) where Element == (T1, T2, T3, T4) {
        reduce(into: ([] as [T1], [] as [T2], [] as [T3], [] as [T4])) { arrays, element in
            arrays.0.append(element.0)
            arrays.1.append(element.1)
            arrays.2.append(element.2)
            arrays.3.append(element.3)
        }
    }
}

private extension Diagnostic.Message {
    static func multipleTweaks() -> Diagnostic.Message {
        .init(.error, "Cannot have more than one Tweak type in a module")
    }
}

// and y'all thought *C* macros were bad
public final class OrionGenerator {

    // Backends should be declared as extensions on the `Backends` enum. The backend
    // "name" is the name of the type minus `Backends.` will be the backend name. Orion
    // will automatically try to import a module with the name OrionBackend_<backend name>
    // if it exists, so it's best to name the backend framework that. If the backend name
    // contains generic args, the <...> is stripped before determining the name of the
    // auto-imported module. If the backend name contains dots, only the first component is
    // used. For example the backend with the type `Backends.Foo.Bar<Int>` should be referred
    // to by the name "Foo.Bar<Int>", and will result in Orion auto-importing `OrionBackend_Foo`.
    // To import additional modules, pass them as `extraBackendModules` to the `generate` method.
    public struct Backend {
        public let name: String
        public let implicitModule: String?

        public init(nameWithoutModule name: String) {
            self.name = name
            self.implicitModule = nil
        }

        public init?(name: String) {
            self.name = name
            guard let beforeGenerics = name.split(separator: "<").first,
                  let beforeDot = beforeGenerics.split(separator: ".").first
            else { return nil }
            self.implicitModule = "OrionBackend_\(beforeDot)"
        }

        public static let `internal`: Self = .init(nameWithoutModule: "Internal")
    }

    public let diagnosticEngine: OrionDiagnosticEngine
    public let data: OrionData

    private var engine: DiagnosticEngine { diagnosticEngine.engine }

    public init(data: OrionData, diagnosticEngine: OrionDiagnosticEngine = .init()) {
        self.data = data
        self.diagnosticEngine = diagnosticEngine
    }

    private func arguments(for function: OrionData.Function) -> [String] {
        (0..<function.numberOfArguments).map { "arg\($0 + 1)" }
    }

    private func generateConcreteMethodData(
        from method: OrionData.ClassHook.Method,
        className: String,
        index: Int
    ) -> (orig: String?, supr: String?, main: String, activation: String) {
        let orig: String?
        let supr: String?
        let register: String

        let args = arguments(for: method.function)
        let argsList = args.joined(separator: ", ")
        let commaArgs = args.isEmpty ? "" : ", \(argsList)"
        let origIdent = "orion_\(method.isAddition ? "imp" : "orig")\(index)"
        let selIdent = "orion_sel\(index)"

        if method.isDeinitializer {
            orig = method.isAddition ? nil : """
            \(method.function.function) {
                deinitOrigError()
            }
            """

            supr = method.isAddition ? nil : """
            \(method.function.function) {
                deinitSuprError()
            }
            """

            register = """
            builder.addDeinitializer(to: self, getOrig: { \(origIdent) }, setOrig: { \(origIdent) = $0 })
            """

            let main = """
            private static var \(origIdent): @convention(c) (Any, Selector) -> Void = { _, _ in }
            """

            return (orig, supr, main, register)
        } else if method.isAddition {
            orig = nil
            supr = nil
            register = """
            addMethod(\(selIdent), \(origIdent), isClassMethod: \(method.isClassMethod))
            """
        } else {
            // While we don't need to add @objc due to the class being @objcMembers (and the #selector
            // failing if the function can't be represented in objc), this results in better diagnostics
            // than merely having an error on the #selector line
            let funcOverride = "\(method.hasObjcAttribute ? "" : "@objc ")\(method.function.function)"

            orig = """
            \(funcOverride) {
                Self.\(origIdent)(target, Self.\(selIdent)\(commaArgs))
            }
            """

            supr = """
            \(funcOverride) {
                callSuper((@convention(c) \(method.superClosure)).self) { $0($1, Self.\(selIdent)\(commaArgs)) }
            }
            """

            register = """
            builder.addHook(\(selIdent), \(origIdent), isClassMethod: \(method.isClassMethod)) { \(origIdent) = $0 }
            """
        }

        // say there's a method foo() and another named foo(bar:). #selector(foo) will result in an error
        // because it could refer to either. Adding the signature disambiguates.
        let selSig = "\(method.isClassMethod ? "" : "(Self) -> ")\(method.function.closure)"
        let main = """
        private static let \(selIdent) = #selector(\(method.function.identifier) as \(selSig))
        private static var \(origIdent): @convention(c) \(method.methodClosure) = { target, _cmd\(commaArgs) in
            \(className)\(method.isClassMethod ? "" : "(target: target)").\(method.function.identifier)(\(argsList))
        }
        """

        return (orig, supr, main, register)
    }

    private func generateConcreteClassHook(from classHook: OrionData.ClassHook, idx: Int) -> (hook: String, name: String) {
        func indentAndJoin(_ elements: [String], by level: Int) -> String {
            guard !elements.isEmpty else { return "" }
            let indent = String(repeating: "    ", count: level)
            let outdent = String(repeating: "    ", count: level - 1)
            let joined = elements.map {
                $0.split(separator: "\n").map { "\(indent)\($0)" }.joined(separator: "\n")
            }.joined(separator: "\n\n")
            return "\n\(joined)\n\(outdent)"
        }

        let className = "Orion_ClassHook\(idx)"

        let (origs, suprs, mains, registers) = classHook.methods.enumerated()
            .map { generateConcreteMethodData(from: $1, className: className, index: $0 + 1) }
            .unzip()

        let indentedOrigs = indentAndJoin(origs.compactMap { $0 }, by: 2)
        let indentedSuprs = indentAndJoin(suprs.compactMap { $0 }, by: 2)
        let indentedMains = indentAndJoin(mains, by: 1)

        let hook = """
        extension \(classHook.name) {
            public static let _target: \(classHook.target).Type = _initializeTargetType()
        }

        private class \(className): \(classHook.name), _GlueClassHook {
            final class OrigType: \(className) {\(indentedOrigs)}

            final class SuprType: \(className) {\(indentedSuprs)}
        \(indentedMains)
            static func activate(withClassHookBuilder builder: inout _ClassHookBuilder) {
                \(registers.joined(separator: "\n        "))
            }
        }
        """

        return (hook, className)
    }

    private func generateConcreteFunctionHook(from functionHook: OrionData.FunctionHook, idx: Int) -> (hook: String, name: String) {
        let className = "Orion_FunctionHook\(idx)"
        let shared = "orion_shared"
        let args = arguments(for: functionHook.function)
        let argsList = args.joined(separator: ", ")
        let argsIn = args.isEmpty ? "" : "\(argsList) in"
        let hook = """
        private class \(className): \(functionHook.name), _GlueFunctionHook {
            static let \(shared) = \(className)()

            static var origFunction: @convention(c) \(functionHook.function.closure) = { \(argsIn)
                \(className).\(shared).\(functionHook.function.identifier)(\(argsList))
            }

            final class OrigType: \(className) {
                \(functionHook.function.function) {
                    Self.origFunction(\(argsList))
                }
            }
        }
        """
        return (hook, className)
    }

    private func join(_ items: [String], separation: String = "\n\n") -> String {
        "\(items.joined(separator: separation))\(items.isEmpty ? "" : "\n\n")"
    }

    public func generate(backend: Backend = .internal, extraBackendModules: Set<String> = []) throws -> String {
        let (classes, classHookNames) = data.classHooks.enumerated()
            .map { generateConcreteClassHook(from: $1, idx: $0 + 1) }
            .unzip()
        let (functions, functionHookNames) = data.functionHooks.enumerated()
            .map { generateConcreteFunctionHook(from: $1, idx: $0 + 1) }
            .unzip()

        let separator = ",\n            "
        let allHookNames = classHookNames + functionHookNames
        let allHooks = allHookNames.map { "\($0).self" }.joined(separator: separator)

        let tweakName: String
        let hasCustomBackend: Bool
        switch data.tweaks.count {
        case 0:
            tweakName = "DefaultTweak"
            hasCustomBackend = false
        case 1:
            let tweak = data.tweaks[0]
            tweakName = "\(tweak.name)"
            hasCustomBackend = tweak.hasBackend
        default:
            engine.diagnose(.multipleTweaks()) { builder in
                self.data.tweaks
                    .map { $0.name.sourceRange(converter: $0.converter) }
                    .forEach { builder.highlight($0) }
            }
            throw OrionFailure()
        }

        let importBackend: String
        if !hasCustomBackend, let module = backend.implicitModule {
            importBackend = """
            \(join(extraBackendModules.sorted().map { "import \($0)" }, separation: "\n"))\
            #if canImport(\(module))
            import \(module)
            #endif\n\n
            """
        } else {
            importBackend = ""
        }

        // While duplicate imports are *technically* fine, de-duplicating them keeps things shorter
        var imports = Set(data.imports.map { "\($0)" })
        imports.insert("import Orion")
        imports.insert("import Foundation")

        return """
        // swiftlint:disable all

        \(join(imports.sorted(), separation: "\n"))\
        \(join(classes))\
        \(join(functions))\
        \(importBackend)\
        @_cdecl("orion_init")
        func orion_init() {
            \(tweakName)().activate(
        \(hasCustomBackend ? "" : "        backend: Backends.\(backend.name)(),\n")\
                hooks: [
                    \(allHooks)
                ]
            )
        }\n
        """
    }

}
