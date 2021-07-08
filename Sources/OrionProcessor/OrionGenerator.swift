import Foundation
import SwiftSyntax

// swiftlint:disable:next superfluous_disable_command
// swiftlint:disable type_body_length file_length

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

private extension SourceLocation {
    func decl() -> String? {
        guard let file = file, let line = line else { return nil }
        // TODO: Maybe escape `file`
        return "#sourceLocation(file: \"\(file)\", line: \(line))"
    }
}

private extension Diagnostic.Message {
    static func multipleTweaks() -> Diagnostic.Message {
        .init(.error, "Cannot have more than one Tweak type in a module")
    }
}

// and y'all thought *C* macros were bad
public final class OrionGenerator {

    public struct Options {
        public var backend: Backend
        public var extraBackendModules: Set<String>
        public var emitSourceLocations: Bool

        public init(
            backend: Backend = .internal,
            extraBackendModules: Set<String> = [],
            emitSourceLocations: Bool = true
        ) {
            self.backend = backend
            self.extraBackendModules = extraBackendModules
            self.emitSourceLocations = emitSourceLocations
        }
    }

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
            guard let beforeGenerics = name.split(separator: "<", omittingEmptySubsequences: false).first,
                  let beforeDot = beforeGenerics.split(separator: ".", omittingEmptySubsequences: false).first,
                  !beforeDot.isEmpty
            else { return nil }
            self.implicitModule = "OrionBackend_\(beforeDot)"
        }

        public static let `internal`: Self = .init(nameWithoutModule: "Internal")
    }

    private let engine: DiagnosticEngine
    public let data: OrionData
    public let options: Options

    public init(data: OrionData, diagnosticEngine: OrionDiagnosticEngine = .init(), options: Options = .init()) {
        self.data = data
        self.engine = diagnosticEngine.createEngine()
        self.options = options
    }

    private func sourceLocDecl(for sourceLocation: SourceLocation) -> String {
        options.emitSourceLocations ? (sourceLocation.decl().map { "\($0)\n" } ?? "") : ""
    }

    private func arguments(for function: OrionData.Function) -> [String] {
        (0..<function.numberOfArguments).map { "arg\($0 + 1)" }
    }

    private func generateConcreteMethodData(
        from method: OrionData.ClassHook.Method,
        className: String,
        index: Int
    ) -> (orig: String?, supr: String?, main: String, activation: String?) {
        let orig: String?
        let supr: String?
        let register: String?

        let args = arguments(for: method.function)
        let argsList = args.joined(separator: ", ")
        let commaArgs = args.isEmpty ? "" : ", \(argsList)"

        // order of operands matters here; we don't want to evaluate isAddition
        // if it's a deinitializer, so that Orion can notify the user if they
        // have a pointless `// orion:new`
        let isAddition = !method.isDeinitializer && method.isAddition()
        let origIdent = "orion_\(isAddition ? "imp" : "orig")\(index)"
        let selIdent = "orion_sel\(index)"

        let returnsRetained = !method.isDeinitializer && method.returnsRetained()
        let takeRetained = returnsRetained ? ".takeRetainedValue()" : ""
        let passRetained = returnsRetained ? "Unmanaged.passRetained" : ""
        let methodClosure = returnsRetained ? method.methodClosureUnmanaged : method.methodClosure

        let loc = sourceLocDecl(for: method.function.location)

        if method.isDeinitializer {
            orig = """
            \(method.function.function) {
                deinitOrigError()
            }
            """

            supr = """
            \(method.function.function) {
                deinitSuprError()
            }
            """

            register = """
            builder.addDeinitializer(to: \(className).self, getOrig: { \(origIdent) }, setOrig: { \(origIdent) = $0 })
            """

            let main = """
            private static var \(origIdent): @convention(c) (Any, Selector) -> Void = { _, _ in }
            """

            return (orig, supr, main, register)
        } else if isAddition {
            orig = nil
            supr = nil
            register = """
            builder.addMethod(\(selIdent), \(origIdent), isClassMethod: \(method.isClassMethod))
            """
        } else {
            let isTramp = method.isSuprTramp()

            // While we don't need to add @objc due to the class being @objcMembers (and the #selector
            // failing if the function can't be represented in objc), this results in better diagnostics
            // than merely having an error on the #selector line
            let funcOverride = "\(method.objcAttribute == nil ? "@objc " : "")\(method.function.function)"

            orig = """
            \(loc)\
            \(funcOverride) {
            \(loc.isEmpty ? "" : "#sourceLocation()\n")\
                \(isTramp ? "trampOrigError()" : "_Glue.\(origIdent)(target, _Glue.\(selIdent)\(commaArgs))\(takeRetained)")
            }
            """

            let superClosure = returnsRetained ? method.superClosureUnmanaged : method.superClosure
            supr = """
            \(loc)\
            \(funcOverride) {
            \(loc.isEmpty ? "" : "#sourceLocation()\n")\
            \(loc)\
                callSuper((@convention(c) \(superClosure)).self) {
            \(loc.isEmpty ? "" : "#sourceLocation()\n")\
                    $0($1, _Glue.\(selIdent)\(commaArgs))\(takeRetained)
                }
            }
            """

            register = isTramp ? nil : """
            builder.addHook(\(selIdent), \(origIdent), isClassMethod: \(method.isClassMethod)) { \(origIdent) = $0 }
            """
        }

        // say there's a method foo() and another named foo(bar:). #selector(foo) will result in an error
        // because it could refer to either. Adding the signature disambiguates.
        let selSig = "\(method.isClassMethod ? "" : "(\(className)) -> ")\(method.function.closure)"
        let main = """
        \(loc)\
        private static let \(selIdent) = #selector(\(className).\(method.function.identifier) as \(selSig))
        \(loc.isEmpty ? "" : "#sourceLocation()\n")\
        \(loc)\
        private static var \(origIdent): @convention(c) \(methodClosure) = { target, _cmd\(commaArgs) in
        \(loc.isEmpty ? "" : "#sourceLocation()\n")\
            \(passRetained)(\(className)\(method.isClassMethod ? "" : "(target: target)").\(method.function.identifier)(\(argsList)))
        }
        """

        return (orig, supr, main, register)
    }

    private func generateConcreteClassHook(
        from classHook: OrionData.ClassHook,
        idx: Int
    ) -> (hook: String, glue: (name: String, availability: String?)) {
        func indentAndJoin(_ elements: [String], by level: Int) -> String {
            guard !elements.isEmpty else { return "" }
            let indent = String(repeating: "    ", count: level)
            let outdent = String(repeating: "    ", count: level - 1)
            let joined = elements.map {
                $0.split(separator: "\n").map { "\(indent)\($0)" }.joined(separator: "\n")
            }.joined(separator: "\n\n")
            return "\n\(joined)\n\(outdent)"
        }

        let (origs, suprs, mains, registers) = classHook.methods.enumerated()
            .map { generateConcreteMethodData(from: $1, className: classHook.name, index: $0 + 1) }
            .unzip()

        let indentedOrigs = indentAndJoin(origs.compactMap { $0 }, by: 3)
        let indentedSuprs = indentAndJoin(suprs.compactMap { $0 }, by: 3)
        let indentedMains = indentAndJoin(mains, by: 2)

        let hook = """
        \(classHook.availability.map { "@available(\($0)) " } ?? "")extension \(classHook.name) {
            enum _Glue: _GlueClassHook {
                typealias HookType = \(classHook.name)

                final class OrigType: \(classHook.name), _GlueClassHookTrampoline {\(indentedOrigs)}

                final class SuprType: \(classHook.name), _GlueClassHookTrampoline {\(indentedSuprs)}

                static let storage = initializeStorage()
        \(indentedMains)
                static func activate(withClassHookBuilder builder: inout _GlueClassHookBuilder) {
                    \(registers.compactMap { $0 }.joined(separator: "\n            "))
                }
            }
        }
        """

        return (hook, ("\(classHook.name)._Glue", classHook.availability.map { "\($0)" }))
    }

    private func generateConcreteFunctionHook(
        from functionHook: OrionData.FunctionHook,
        idx: Int
    ) -> (hook: String, glue: (name: String, availability: String?)) {
        let loc = sourceLocDecl(for: functionHook.function.location)
        let args = arguments(for: functionHook.function)
        let argsList = args.joined(separator: ", ")
        let argsIn = args.isEmpty ? "" : "\(argsList) in"
        let hook = """
        \(functionHook.availability.map { "@available(\($0)) " } ?? "")extension \(functionHook.name) {
            enum _Glue: _GlueFunctionHook {
                typealias HookType = \(functionHook.name)

                final class OrigType: \(functionHook.name), _GlueFunctionHookTrampoline {
                    \(functionHook.function.function) {
                        _Glue.origFunction(\(argsList))
                    }
                }

        \(loc)\
                static var origFunction: @convention(c) \(functionHook.function.closure) = { \(argsIn)
        \(loc.isEmpty ? "" : "#sourceLocation()\n")\
                    \(functionHook.name)().\(functionHook.function.identifier)(\(argsList))
                }

                static let storage = initializeStorage()
            }
        }
        """
        return (hook, ("\(functionHook.name)._Glue", functionHook.availability.map { "\($0)" }))
    }

    private func join(_ items: [String], separation: String = "\n\n") -> String {
        "\(items.joined(separator: separation))\(items.isEmpty ? "" : "\n\n")"
    }

    public func generate() throws -> String {
        let (classes, classHookGlues) = data.classHooks.enumerated()
            .map { generateConcreteClassHook(from: $1, idx: $0 + 1) }
            .unzip()
        let (functions, functionHookGlues) = data.functionHooks.enumerated()
            .map { generateConcreteFunctionHook(from: $1, idx: $0 + 1) }
            .unzip()

        let separator = ",\n            "
        let allHookGlues = classHookGlues + functionHookGlues
        let gluesByAvailability: [String?: [String]] = [String?: [(String, String?)]](grouping: allHookGlues) { $0.1 }
            .mapValues { $0.map { "\($0.0).self" } }
        let allHooks = gluesByAvailability.map { availability, glues in
            """
                if \(availability.map { "#available(\($0))" } ?? "true") {
                    hooks += [
                        \(glues.joined(separator: separator))
                    ]
                }
            """
        }.sorted().joined(separator: "\n")

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
        if !hasCustomBackend, let module = options.backend.implicitModule {
            importBackend = """
            \(join(options.extraBackendModules.sorted().map { "import \($0)" }, separation: "\n"))\
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

        // Note: we do var hooks...\nhooks=[] instead of declaring on
        // one line because the latter would result in a warning about
        // `var hooks` not being mutated if there were no hooks.
        return """
        // ###
        // # AUTOGENERATED ORION GLUE FILE. DO NOT EDIT.
        // ###

        // orion:disable
        // swiftlint:disable all

        \(join(imports.sorted(), separation: "\n"))\
        \(join(classes))\
        \(join(functions))\
        \(importBackend)\
        @_cdecl("orion_init")
        func orion_init() {
            var hooks: [_GlueAnyHook.Type]
            hooks = []
        \(allHooks)
            \(tweakName)._activate(
        \(hasCustomBackend ? "" : "        backend: Backends.\(options.backend.name)(),\n")\
                hooks: hooks
            )
        }\n
        """
    }

}
