import Foundation

public protocol _AnyHook {
    // Return true to continue activation, false to skip. Default implementation
    // always returns true.
    static func willActivate() -> Bool
    static func didActivate()
}

extension _AnyHook {
    public static func willActivate() -> Bool { true }
    public static func didActivate() {}
}

public protocol _ConcreteHook: _AnyHook {
    // we can't use HookBuilder as an existential here because that would allow the
    // function to re-assign the builder to one of a different type
    static func activate<Builder: HookBuilder>(withHookBuilder builder: inout Builder)
}
