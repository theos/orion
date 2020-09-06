import Foundation

public protocol HookBuilder {
    // avoid performing side-effects (such as actually swizzling) in these methods; any side-effects should
    // occur after the build block in the corresponding `Backend.hook` method. The builder should only serve
    // to store hook *requests*, and the backend should actually perform these requests.
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
        // guaranteed to have been called once `hook` is complete
        var code: Code?
        hook {
            $0.addFunctionHook(function, replacement: replacement) { code = $0 }
        }
        guard let unwrapped = code
            else { fatalError("Hook builder did not call function hook completion") }
        return unwrapped
    }

    public func hookMethod<Code>(cls: AnyClass, sel: Selector, replacement: Code) -> Code {
        var code: Code?
        hook {
            $0.addMethodHook(cls: cls, sel: sel, replacement: replacement) { code = $0 }
        }
        guard let unwrapped = code
            else { fatalError("Hook builder did not call method hook completion") }
        return unwrapped
    }
}

// a backend which can be specified as a default
public protocol DefaultBackend: Backend {
    init()
}
