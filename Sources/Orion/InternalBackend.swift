import Foundation

public struct InternalBackend: DefaultBackend {
    public init() {}

    public struct Builder: HookBuilder {
        public func addFunctionHook<Code>(_ function: Function, replacement: Code, completion: (Code) -> Void) {
            fatalError("The internal backend does not support function hooking")
        }

        public func addMethodHook<Code>(cls: AnyClass, sel: Selector, replacement: Code, completion: (Code) -> Void) {
            guard let method = class_getInstanceMethod(cls, sel) else {
                let isMeta = class_isMetaClass(cls)
                let methodDescription = "\(isMeta ? "+" : "-")[\(cls) \(sel)]"
                fatalError("Could not find method \(methodDescription)")
            }
            completion(unsafeBitCast(
                method_setImplementation(method, unsafeBitCast(replacement, to: IMP.self)),
                to: Code.self
            ))
        }
    }

    public func hook(_ build: (inout Builder) -> Void) {
        var builder = Builder()
        build(&builder)
    }
}
