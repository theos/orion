import Foundation

/// Base protocol requirements for hooks. Do not use this directly.
///
/// - See: `ClassHook`, and `FunctionHook`.
public protocol AnyHook {

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

/// :nodoc:
extension AnyHook {
    public static func hookWillActivate() -> Bool { true }
    public static func hookDidActivate() {}
}

/// A protocol that is implemented in Orion's glue file for each
/// hook, which performs the actual hooking.
///
/// This protocol (and its refinements) serve as the bridge between
/// the user's code and the glue file. For every hook that the user
/// declares, the glue file extends it with a `_Glue` associatedtype
/// that conforms to one of the `_Glue*Hook` types and contains the
/// actual hook implementation.
///
/// The source files still compile in the absence of such an extension
/// since the `_Glue` associatedtype has a placeholder value, which
/// allows SourceKit to play nicely with the user's source files even
/// if the glue file hasn't been compiled yet. On the other hand, if
/// the glue file _is_ compiled then the compiler prefers the `_Glue`
/// type provided by the glue file's extensions over the placeholder,
/// which changes the code's behavior and enables it to actually perform
/// the desired hooking.
///
/// :nodoc:
public protocol _GlueAnyHook {

    /// Activates the hook. Do not call this directly.
    ///
    /// - Parameter tweak: The tweak to which the hook belongs.
    static func activate(in tweak: Tweak.Type) -> [HookDescriptor]

    /// Trampoline for `AnyHook.hookWillActivate()`. Do not call
    /// this directly.
    static func hookWillActivate() -> Bool

    /// Trampoline for `AnyHook.hookDidActivate()`. Do not call
    /// this directly.
    static func hookDidActivate()

    /// The type-erased `HookGroup` associated with this hook. Do
    /// not use this yourself.
    static var groupType: HookGroup.Type { get }

}
