import Foundation

public struct InternalBackend: DefaultBackend {
    public init() {}

    public struct Builder: HookBuilder {
        fileprivate var actions: [() -> Void] = []

        public func addFunctionHook<Code>(_ function: Function, replacement: Code, completion: (Code) -> Void) {
            fatalError("The internal backend does not support function hooking")
        }

        public mutating func addMethodHook<Code>(cls: AnyClass, sel: Selector, replacement: Code, completion: @escaping (Code) -> Void) {
            guard let method = class_getInstanceMethod(cls, sel) else {
                let isMeta = class_isMetaClass(cls)
                let methodDescription = "\(isMeta ? "+" : "-")[\(cls) \(sel)]"
                fatalError("Could not find method \(methodDescription)")
            }
            actions.append {
                completion(unsafeBitCast(
                    method_setImplementation(method, unsafeBitCast(replacement, to: IMP.self)),
                    to: Code.self
                ))
            }
        }
    }

    public func hook(_ build: (inout Builder) -> Void) {
        var builder = Builder()
        build(&builder)
        builder.actions.forEach { $0() }
    }
}
