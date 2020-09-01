import Foundation
import SwiftSyntax

private extension Sequence {
    func unzip<T1, T2>() -> ([T1], [T2]) where Element == (T1, T2) {
        reduce(into: ([] as [T1], [] as [T2])) { arrays, element in
            arrays.0.append(element.0)
            arrays.1.append(element.1)
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

    public struct Backend {
        public let name: String
        public let module: String?

        public init(name: String, module: String? = nil) {
            self.name = name
            self.module = module
        }

        public static let `internal`: Self = .init(name: "InternalBackend")
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

    private func generateConcreteMethodHook(
        from method: OrionData.ClassHook.Method,
        className: String,
        index: Int
    ) -> (hook: String, register: String) {
        let args = arguments(for: method.function)
        let argsList = args.joined(separator: ", ")
        let commaArgs = args.isEmpty ? "" : ", \(argsList)"
        let orig = "orion_orig\(index)"
        let sel = "orion_sel\(index)"
        // say there's a method foo() and another named foo(bar:). #selector(foo) will result in an error
        // because it could refer to either. Adding the signature disambiguates.
        let selSig = "\(method.isClassMethod ? "" : "(Self) -> ")\(method.function.closure)"
        let hook = """
        private static var \(orig): @convention(c) \(method.methodClosure) = { target, _cmd\(commaArgs) in
            \(className)\(method.isClassMethod ? "" : "(target: target)").\(method.function.identifier)(\(argsList))
        }
        private static let \(sel) = #selector(\(method.function.identifier) as \(selSig))
        \(method.hasObjcAttribute ? "" : "@objc ")\(method.function.function) {
            switch callState.fetchRequest() {
            case nil, .selfCall:
                return super.\(method.function.identifier)(\(argsList))
            case .origCall:
                return Self.\(orig)(target, Self.\(sel)\(commaArgs))
            case .superCall:
                return callSuper((@convention(c) \(method.superClosure)).self) { $0($1, Self.\(sel)\(commaArgs)) }
            }
        }
        """

        let register = """
        register(backend, \(sel), &\(orig), isClassMethod: \(method.isClassMethod))
        """

        return (hook, register)
    }

    private func generateConcreteClassHook(from classHook: OrionData.ClassHook, idx: Int) -> (hook: String, name: String) {
        let className = "Orion_ClassHook\(idx)"

        let (methods, registers) = classHook.methods.enumerated()
            .map { generateConcreteMethodHook(from: $1, className: className, index: $0 + 1) }
            .unzip()

        let indentedMethods = methods.map {
            $0.split(separator: "\n").map { "    \($0)" }.joined(separator: "\n")
        }.joined(separator: "\n\n")

        let hook = """
        private final class \(className): \(classHook.name), ConcreteClassHook {
            static let callState = CallState<ClassRequest>()
            let callState = CallState<ClassRequest>()

        \(indentedMethods)

            static func activate(withBackend backend: Backend) {
                \(registers.joined(separator: "\n        "))
            }
        }
        """

        return (hook, className)
    }

    private func generateConcreteFunctionHook(from functionHook: OrionData.FunctionHook, idx: Int) -> (hook: String, name: String) {
        let className = "Orion_FunctionHook\(idx)"
        let args = arguments(for: functionHook.function)
        let argsList = args.joined(separator: ", ")
        let argsIn = args.isEmpty ? "" : "\(argsList) in"
        let hook = """
        private final class \(className): \(functionHook.name), ConcreteFunctionHook {
            let callState = CallState<FunctionRequest>()

            static var origFunction: @convention(c) \(functionHook.function.closure) = { \(argsIn)
                \(className)().\(functionHook.function.identifier)(\(argsList))
            }

            \(functionHook.function.function) {
                switch callState.fetchRequest() {
                case nil:
                    return super.\(functionHook.function.identifier)(\(argsList))
                case .origCall:
                    return Self.origFunction(\(argsList))
                }
            }
        }
        """
        return (hook, className)
    }

    private func join(_ items: [String], separation: String = "\n\n") -> String {
        "\(items.joined(separator: separation))\(items.isEmpty ? "" : "\n\n")"
    }

    public func generate(backend: Backend = .internal) throws -> String {
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
        if !hasCustomBackend, let module = backend.module {
            importBackend = "import \(module)\n\n"
        } else {
            importBackend = ""
        }

        // we might end up with duplicate imports but Swift accepts those so it's *technically* fine, but,
        // TODO: Try to de-duplicate imports just to keep things shorter
        return """
        import Orion
        import Foundation
        \(join(data.imports.map { "\($0)" }, separation: "\n"))\
        \(join(classes))\
        \(join(functions))\
        \(importBackend)\
        @_cdecl("__orion_constructor")
        func __orion_constructor() {
            \(tweakName)().activate(
                \(hasCustomBackend ? "" : "backend: \(backend.name)(),\n")\
                hooks: [
                    \(allHooks)
                ]
            )
        }
        """
    }

}
