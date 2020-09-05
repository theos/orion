import Foundation

// I can't think of a better name, sorry
public protocol Hooker {
    mutating func addFunctionHook<Code>(_ function: Function, replacement: Code, completion: @escaping (Code) -> Void)
    mutating func addMethodHook<Code>(cls: AnyClass, sel: Selector, replacement: Code, completion: @escaping (Code) -> Void)

    // Calling this more than once is undefined behaviour. All completions must be invoked by the end of this method.
    mutating func finalize()
}

extension Hooker {
    public func finalize() {}
}

public protocol Backend {
    func makeHooker() -> Hooker
}

extension Backend {
    // The hooker is finalized after the block is called. Do not finalize it within the block.
    public func withHooker<Result>(_ block: (inout Hooker) throws -> Result) rethrows -> Result {
        var hooker = makeHooker()
        defer { hooker.finalize() }
        return try block(&hooker)
    }

    // For one-off hooks. Prefer batching if possible.

    public func hookFunction<Code>(_ function: Function, replacement: Code) -> Code {
        // NOTE: We can't declare `code` inside the block because `completion` is only
        // guaranteed to have been called once `withHooker` is complete
        var code: Code!
        withHooker { $0.addFunctionHook(function, replacement: replacement) { code = $0 } }
        return code
    }

    public func hookMethod<Code>(cls: AnyClass, sel: Selector, replacement: Code) -> Code {
        var code: Code!
        withHooker { $0.addMethodHook(cls: cls, sel: sel, replacement: replacement) { code = $0 } }
        return code
    }
}

// a backend which can be specified as a default
public protocol DefaultBackend: Backend {
    init()
}
