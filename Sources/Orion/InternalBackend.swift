import Foundation

public struct InternalBackend: DefaultBackend {
    public init() {}

    public struct Builder: HookBuilder {
        fileprivate var actions: [() -> Void] = []

        public func addFunctionHook(
            _ function: Function,
            replacement: UnsafeMutableRawPointer,
            completion: (UnsafeMutableRawPointer) -> Void
        ) {
            fatalError("The internal backend does not support function hooking")
        }

        public mutating func addMethodHook(
            cls: AnyClass,
            sel: Selector,
            replacement: UnsafeMutableRawPointer,
            completion: @escaping (UnsafeMutableRawPointer) -> Void
        ) {
            guard let method = class_getInstanceMethod(cls, sel) else {
                let isMeta = class_isMetaClass(cls)
                let methodDescription = "\(isMeta ? "+" : "-")[\(cls) \(sel)]"
                fatalError("Could not find method \(methodDescription)")
            }
            actions.append {
                completion(.init(method_setImplementation(method, .init(replacement))))
            }
        }
    }

    public func hook(_ build: (inout Builder) -> Void) {
        var builder = Builder()
        build(&builder)
        builder.actions.forEach { $0() }
    }
}
