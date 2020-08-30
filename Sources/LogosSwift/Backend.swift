import Foundation

public protocol Backend {
    func hookFunction<Code>(_ function: Function, replacement: Code) -> Code
    func hookMethod<Code>(cls: AnyClass, sel: Selector, replacement: Code) -> Code
}

// a backend which can be specified as a default
public protocol DefaultBackend: Backend {
    init()
}

public struct InternalBackend: DefaultBackend {
    public func hookFunction<Code>(_ function: Function, replacement: Code) -> Code {
        // TODO: Add the fatal error back once the tests can handle this better
//        fatalError("The internal backend does not support function hooking")
        replacement
    }

    public func hookMethod<Code>(cls: AnyClass, sel: Selector, replacement: Code) -> Code {
        guard let method = class_getInstanceMethod(cls, sel) else {
            let isMeta = class_isMetaClass(cls)
            let methodDescription = "\(isMeta ? "+" : "-")[\(cls) \(sel)]"
            fatalError("Could not find method \(methodDescription)")
        }
        return unsafeBitCast(
            method_setImplementation(method, unsafeBitCast(replacement, to: IMP.self)),
            to: Code.self
        )
    }

    public init() {}
}
