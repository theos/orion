import Foundation

private extension Sequence {
    func unzip<T1, T2>() -> ([T1], [T2]) where Element == (T1, T2) {
        reduce(into: ([] as [T1], [] as [T2])) { arrays, element in
            arrays.0.append(element.0)
            arrays.1.append(element.1)
        }
    }
}

public final class LogosGenerator {

    public let data: LogosData
    public init(data: LogosData) {
        self.data = data
    }

    private func arguments(for function: LogosData.Function) -> [String] {
        (0..<function.numberOfArguments).map { "arg\($0 + 1)" }
    }

    private func generateConcreteMethodHook(
        from method: LogosData.ClassHook.Method,
        className: String,
        index: Int
    ) -> (hook: String, register: String) {
        let args = arguments(for: method.function)
        let argsList = args.joined(separator: ", ")
        let commaArgs = args.isEmpty ? "" : ", \(argsList)"
        let function = "Logos_Function\(index)"
        let orig = "logos_orig\(index)"
        let sel = "logos_sel\(index)"
        let hook = """
        private typealias \(function) = \(method.function.closure)
        private static var \(orig): \(function) = { target, _cmd\(commaArgs) in
            \(className)\(method.isClassMethod ? "" : "(target: target)").\(method.function.identifier)(\(argsList))
        }
        private static let \(sel) = #selector(\(method.function.identifier))
        \(method.hasObjcAttribute ? "" : "@objc ")\(method.function.function) {
            switch callState.fetchRequest() {
            case nil:
                return super.\(method.function.identifier)(\(argsList))
            case .origCall:
                return Self.\(orig)(target, Self.\(sel)\(commaArgs))
            case .superCall:
                return callSuper(\(function).self) { $0($1, Self.\(sel)\(commaArgs)) }
            }
        }
        """

        let register = """
        register(backend, \(sel), &\(orig), isClassMethod: \(method.isClassMethod))
        """

        return (hook, register)
    }

    private func generateConcreteClassHook(from classHook: LogosData.ClassHook) -> (hook: String, name: String) {
        let className = "Logos_ConcreteClassHook_\(classHook.name)"

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

    private func generateConcreteFunctionHook(from functionHook: LogosData.FunctionHook) -> (hook: String, name: String) {
        let className = "Logos_ConcreteFunctionHook_\(functionHook.name)"
        let args = arguments(for: functionHook.function)
        let argsList = args.joined(separator: ", ")
        let argsIn = args.isEmpty ? "" : "\(argsList) in"
        let hook = """
        private final class \(className): \(functionHook.name), ConcreteFunctionHook {
            let callState = CallState<FunctionRequest>()

            static var origFunction: \(functionHook.function.closure) = { \(argsIn)
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

    public func generate(backend: String, backendModule: String?) throws -> String {
        let (classes, classHookNames) = data.classHooks.map(generateConcreteClassHook).unzip()
        let (functions, functionHookNames) = data.functionHooks.map(generateConcreteFunctionHook).unzip()

        let separator = ",\n            "
        let allHookNames = classHookNames + functionHookNames
        let allHooks = allHookNames.map { "\($0).self" }.joined(separator: separator)

        let tweakName: String
        let hasCustomBackend: Bool
        let customTweakDecl: String
        switch data.tweaks.count {
        case 0:
            tweakName = "Logos_Tweak"
            hasCustomBackend = false
            customTweakDecl = "private struct \(tweakName): Tweak {}"
        case 1:
            let tweak = data.tweaks[0]
            tweakName = "\(tweak.name)"
            hasCustomBackend = tweak.hasBackend
            customTweakDecl = ""
        default:
            // TODO: Emit error to DiagnosticConsumer
            throw LogosFailure()
        }

        let importStatement: String
        if !hasCustomBackend, let module = backendModule {
            importStatement = "import \(module)"
        } else {
            importStatement = ""
        }

        // we might end up with duplicate imports but Swift accepts those so it's fine
        return """
        import LogosSwift
        import Foundation
        \(data.imports.map { "\($0)" }.joined(separator: "\n"))

        \(classes.joined(separator: "\n"))

        \(functions.joined(separator: "\n"))

        \(customTweakDecl)

        \(importStatement)

        @_cdecl("__logos_swift_constructor")
        func __logos_swift_constructor() {
            \(tweakName)().activate(
                \(hasCustomBackend ? "" : "backend: \(backend)(),")
                hooks: [
                    \(allHooks)
                ]
            )
        }
        """
    }

}
