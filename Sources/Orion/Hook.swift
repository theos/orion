import Foundation

public protocol AnyHook {
    static var shouldActivate: Bool { get }
}

extension AnyHook {
    public static var shouldActivate: Bool { true }
}

public protocol ConcreteHook: AnyHook {
    // we can't use HookBuilder as an existential here because that would allow the
    // function to re-assign the builder to one of a different type
    static func activate<Builder: HookBuilder>(withHookBuilder builder: inout Builder)
}
