import Foundation

/// The base existential protocol for all hook types. Do not use this directly.
///
/// - See: `AnyHook`, `ClassHook`, and `FunctionHook`.
public protocol AnyHookBase {
    // This protocol should never have any Self/PAT requirements, to allow it to be
    // usable as an existential. To add a Self/PAT requirement, use `AnyHook`.

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

/// Additional protocol requirements for hooks, beyond those of `AnyHookBase`.
/// Do not use this directly.
///
/// - See: `AnyHookBase`, `ClassHook`, and `FunctionHook`.
public protocol AnyHook: AnyHookBase {

    /// The `HookGroup` to which this hook is assigned.
    ///
    /// Defaults to `DefaultGroup`.
    ///
    /// - See: `HookGroup`
    associatedtype Group: HookGroup = DefaultGroup

    /// The `HookGroup` associated with this hook type.
    ///
    /// Do not attempt to implement this yourself; use the default
    /// implementation.
    static var group: Group { get }

}

extension AnyHookBase {
    public static func hookWillActivate() -> Bool { true }
    public static func hookDidActivate() {}
}

/// A concrete hook, implemented in the glue file. Do not use
/// this directly.
///
/// :nodoc:
public protocol _AnyGlueHook: AnyHookBase {

    /// Activates the hook. Do not call this directly.
    static func activate() -> [HookDescriptor]

    /// The type-erased `HookGroup` associated with this hook. Do
    /// not use this yourself.
    static var groupType: HookGroup.Type { get }

}

/// :nodoc:
extension _AnyGlueHook where Self: AnyHook {
    public static var groupType: HookGroup.Type { Group.self }
}
