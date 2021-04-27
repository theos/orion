import Foundation

/// A type describing a single hook.
public enum HookDescriptor {

    /// A closure used to save the original implementation or handle errors.
    public typealias Completion = (Result<UnsafeMutableRawPointer, Error>) -> Void

    /// A method hook.
    ///
    /// `replacement` represents an Objective-C method `IMP`. It should be a `@convention(c)`
    /// function which takes `self: AnyObject` and `_cmd: Selector` as its first two arguments.
    /// The remaining argument types should be the argument types of the hooked Objective-C method
    /// in order, and the return type should be the return type of the method.
    ///
    /// If a class method is being hooked, `cls` should be the metaclass.
    ///
    /// `completion` is a closure which will be passed the original method implementation when the
    /// hook is applied, or an error on failure. It may be called more than once during the duration
    /// of `Backend.apply(descriptors:)`.
    case method(cls: AnyClass, sel: Selector, replacement: UnsafeMutableRawPointer, completion: Completion)

    /// A function hook.
    ///
    /// `replacement` should be a `@convention(c)` function with the same signature as the function
    /// which is to be hooked.
    ///
    /// `completion` is a closure which will be passed the original method implementation when the
    /// hook is applied, or an error on failure. It may be called more than once during the duration
    /// of `Backend.apply(descriptors:)`.
    case function(function: Function, replacement: UnsafeMutableRawPointer, completion: Completion)

}

/// The type that handles hooking of methods and functions.
///
/// Unless you have specific requirements, you should be able to use one
/// of the pre-defined backends declared on `Backends`.
///
/// If you are creating a custom `Backend` implementation which is intended
/// for distribution, declare it as a nested type in an extension on the
/// `Backends` enumeration. The backend's name (which is understood by the
/// Orion CLI) is then the type name minus the `Backends.` prefix.
///
/// If a custom backend name is specified via the Orion CLI, Orion will
/// automatically attempt to import a module named `OrionBackend_<backend name>`
/// if it exists, so it is recommended that you follow this nomenclature while
/// naming your framework. Note that when determining the framework name, any
/// generic arguments are stripped from the type name, and only the first
/// component of the name is used.
///
/// For example, a backend with the type `Backends.Foo.Bar<Int>` will be referred
/// to by the name `Foo.Bar<Int>`, and Orion will attempt to auto-import a module
/// named `OrionBackend_Foo`.
public protocol Backend {

    /// Hooks the provided functions and methods.
    ///
    /// - Parameter descriptors: The descriptors for the hooks to be applied.
    func apply(descriptors: [HookDescriptor])

}

extension Backend {
    func activate(hooks: [_GlueAnyHook.Type], in tweak: Tweak.Type) {
        let hooksToActivate = hooks.filter { $0.hookWillActivate() }
        apply(descriptors: hooksToActivate.flatMap { $0.activate(in: tweak) })
        hooksToActivate.forEach { $0.hookDidActivate() }
    }
}

// We don't have one-off hooking methods because some origs need to be saved before
// hooking is complete since e.g. fishhook uses strcmp during hooking itself which
// means the orig must be saved before the hook returns (see the FishhookBackend
// comments for more info).

/// A backend which Orion can use as a default.
public protocol DefaultBackend: Backend {

    /// Initializes the backend with a default configuration.
    init()

}

/// A namespace to which `Backend`s are added as nested types.
public enum Backends {}
