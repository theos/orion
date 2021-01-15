import Foundation

/// A type describing a single hook.
public enum HookDescriptor {

    /// The completion handler type. The closure is passed the original implementation.
    public typealias Completion = (UnsafeMutableRawPointer) -> Void

    /// A method hook.
    ///
    /// `replacement` represents an Objective-C method `IMP`. It should be a `@convention(c)`
    /// function which takes `self: AnyObject` and `_cmd: Selector` as its first two arguments.
    /// The remaining argument types should be the argument types of the hooked Objective-C method
    /// in order, and the return type should be the return type of the method.
    case method(cls: AnyClass, sel: Selector, replacement: UnsafeMutableRawPointer, completion: Completion)

    /// A function hook.
    ///
    /// `replacement` should be a `@convention(c)` function with the same signature as the function
    /// which is to be hooked.
    case function(function: Function, replacement: UnsafeMutableRawPointer, completion: Completion)

}

/// The type that handles hooking of methods and functions.
///
/// Unless you have specific requirements, you should be able to use one
/// of the pre-defined backends declared on `Backends`.
///
/// If you are creating a custom `Backend` implementation which is intended
/// for distribution, declare it as a nested type in an extension on the
/// `Backends` enumeration. The backend's name is then the type name minus
/// the `Backends.` prefix.
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
///
/// For more information on backends, consult the Orion CLI documentation.
public protocol Backend {

    /// Hooks the provided functions and methods.
    ///
    /// - Parameter hooks: The descriptors for the hooks to be applied.
    func apply(hooks: [HookDescriptor])

}

extension Backend {

    /// Performs a one-off function hook.
    ///
    /// - Parameter function: The function which is to be hooked.
    ///
    /// - Parameter replacement: The replacement function implementation. See
    /// `HookDescriptor.function(function:replacement:completion:)` for details.
    ///
    /// - Returns: The original function implementation.
    ///
    /// Prefer batching with `apply(hooks:)` if you have multiple hooks, as backends
    /// may be able to optimize batch hooking.
    public func hookFunction(_ function: Function, replacement: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
        // NOTE: We can't declare `code` inside the block because `completion` is only
        // guaranteed to have been called once `hook` is complete
        var orig: UnsafeMutableRawPointer?
        apply(hooks: [.function(function: function, replacement: replacement) { orig = $0 }])
        guard let unwrapped = orig
            else { orionError("Hook builder did not call function hook completion") }
        return unwrapped
    }

    /// Performs a one-off method hook.
    ///
    /// - Parameter cls: The class which contains the method to be hooked.
    ///
    /// - Parameter sel: The selector of the method to be hooked.
    ///
    /// - Parameter replacement: The replacement method implementation. See
    /// `HookDescriptor.method(cls:sel:replacement:completion:)` for details.
    ///
    /// - Returns: The original method implementation.
    ///
    /// Prefer batching with `apply(hooks:)` if you have multiple hooks, as backends
    /// may be able to optimize batch hooking.
    public func hookMethod(cls: AnyClass, sel: Selector, replacement: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
        var orig: UnsafeMutableRawPointer?
        apply(hooks: [.method(cls: cls, sel: sel, replacement: replacement) { orig = $0 }])
        guard let unwrapped = orig
            else { orionError("Hook builder did not call method hook completion") }
        return unwrapped
    }

}

/// A backend which Orion can use as a default.
public protocol DefaultBackend: Backend {

    /// Initializes the backend with a default configuration.
    init()

}

/// A namespace to which `Backend`s are added as nested types.
public enum Backends {}
