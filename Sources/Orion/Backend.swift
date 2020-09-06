import Foundation

public protocol HookBuilder {
    mutating func addFunctionHook<Code>(_ function: Function, replacement: Code, completion: @escaping (Code) -> Void)
    mutating func addMethodHook<Code>(cls: AnyClass, sel: Selector, replacement: Code, completion: @escaping (Code) -> Void)
}

public protocol Backend {
    associatedtype Builder: HookBuilder
    func hook(_ build: (inout Builder) -> Void)
}

extension Backend {
    // For one-off hooks. Prefer batching if possible.

    public func hookFunction<Code>(_ function: Function, replacement: Code) -> Code {
        // NOTE: We can't declare `code` inside the block because `completion` is only
        // guaranteed to have been called once `withHooker` is complete
        var code: Code!
        hook { $0.addFunctionHook(function, replacement: replacement) { code = $0 } }
        return code
    }

    public func hookMethod<Code>(cls: AnyClass, sel: Selector, replacement: Code) -> Code {
        var code: Code!
        hook { $0.addMethodHook(cls: cls, sel: sel, replacement: replacement) { code = $0 } }
        return code
    }
}

// a backend which can be specified as a default
public protocol DefaultBackend: Backend {
    init()
}
