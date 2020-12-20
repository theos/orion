import Foundation

public protocol _AnyHook {
    // these are named hook[Will|Did]Activate instead of [will|did]Activate because
    // they're special cased in the generator so that in class hooks, we don't end
    // up thinking the user wants to hook methods by those names in the target class.
    // If they *do* want to hook a method that's actually called hook[Did|Will]Activate,
    // they can name it differently in swift and declare the objc name with @objc(blah).
    // Coming back to the question, hook[Will|Did]Activate is a much rarer method name
    // in apps than [will|did]Activate so it's safer to make the assumption that they're
    // to satisfy the protocol conformance if we go with the former names.

    // Return true to continue activation, false to skip. Default implementation
    // always returns true.
    static func hookWillActivate() -> Bool
    static func hookDidActivate()
}

extension _AnyHook {
    public static func hookWillActivate() -> Bool { true }
    public static func hookDidActivate() {}
}

public protocol _AnyGlueHook: _AnyHook {
    static func activate() -> [HookDescriptor]
}

extension _AnyGlueHook {

    // activate the hook, handling lifecycle logic
    static func activateIfNeeded() -> [HookDescriptor]? {
        guard hookWillActivate() else { return nil }
        return activate()
    }

}
