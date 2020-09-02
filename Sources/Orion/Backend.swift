import Foundation

public protocol Backend {
    func hookFunction<Code>(_ function: Function, replacement: Code) -> Code
    func hookMethod<Code>(cls: AnyClass, sel: Selector, replacement: Code) -> Code
}

// a backend which can be specified as a default
public protocol DefaultBackend: Backend {
    init()
}
