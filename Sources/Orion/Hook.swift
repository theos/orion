import Foundation

/// The base protocol for all hook types. Do not use this directly.
///
/// See `ClassHook` and `FunctionHook`.
public protocol AnyHook {
    // these are named hook[Will|Did]Activate instead of [will|did]Activate because
    // they're special cased in the generator so that in class hooks, we don't end
    // up thinking the user wants to hook methods by those names in the target class.
    // If they *do* want to hook a method that's actually called hook[Did|Will]Activate,
    // they can name it differently in swift and declare the objc name with @objc(blah).
    // Coming back to the question, hook[Will|Did]Activate is a much rarer method name
    // in apps than [will|did]Activate so it's safer to make the assumption that they're
    // to satisfy the protocol conformance if we go with the former names.

    /// Called before the hook is activated.
    ///
    /// - Returns: `true` to continue activation, `false` to skip. The default
    /// implementation simply returns `true`.
    static func hookWillActivate() -> Bool

    /// Called after the hook is activated.
    ///
    /// The default implementation does nothing.
    static func hookDidActivate()
}

extension AnyHook {
    public static func hookWillActivate() -> Bool { true }
    public static func hookDidActivate() {}
}

/// A concrete hook, implemented in the glue file. Do not use
/// this directly.
///
/// :nodoc:
public protocol _AnyGlueHook: AnyHook {

    /// Activates the hook. Do not call this directly.
    static func activate() -> [HookDescriptor]

}
