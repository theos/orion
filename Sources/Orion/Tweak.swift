import Foundation
#if SWIFT_PACKAGE
@_implementationOnly import OrionC
#endif

/// A type representing an Orion tweak.
///
/// A module should contain zero or one types conforming to this
/// protocol. If there are zero, Orion will use `DefaultTweak`.
///
/// Tweaks will default to the backend specified via the Orion CLI.
/// In order to override the backend programmatically, conform to
/// `TweakWithBackend` instead.
public protocol Tweak {

    /// The tweak's initializer and entry point.
    ///
    /// Use this method to perform any custom initialization behavior before
    /// `DefaultGroup` is activated. To perform initialization behavior after
    /// `DefaultGroup` is activated, implement `tweakDidActivate()` instead.
    ///
    /// - Warning: This method is called at launch time, even before `main`
    /// has been invoked. Do not synchronously perform any time-consuming
    /// tasks here, because they will make the target process launch slowly.
    init()

    /// Called after all of the tweak's hooks that are in `DefaultGroup` have
    /// been activated. The default implementation does nothing.
    func tweakDidActivate()

    /// Handles errors that occur during hooking.
    ///
    /// The default implementation simply forwards to `handleErrorDefault(_:)`,
    /// which logs and terminates the process. If you implement this method
    /// yourself, however, you can choose to **not** terminate the process.
    ///
    /// This method may be called even before `Tweak.init()` is called.
    ///
    /// - Parameter error: The error that occurred.
    static func handleError(_ error: OrionHookError)

}

extension Tweak {

    /// Activates the tweak. Do not call this yourself.
    ///
    /// :nodoc:
    public static func _activate<BackendType: Backend>(backend: BackendType, hooks: [_GlueAnyHook.Type]) {
        #if SWIFT_PACKAGE
        // this is effectively a no-op but we need it in order to prevent the
        // compiler from stripping out the constructor because it doesn't see
        // it being used
        _orion_init_c()
        #endif

        // this must happen before we init `Tweak` because the tweak might want
        // to activate groups in its `init`.
        let defaultHooks = GroupRegistry.shared.register(hooks, tweak: Self.self, backend: backend)

        let tweak = Self()
        backend.activate(hooks: defaultHooks, in: Self.self)
        tweak.tweakDidActivate()
    }

    public func tweakDidActivate() {}

    /// The default implementation of `handleError(_:)`.
    ///
    /// This method forwards to `orionError(_:file:line:)`, thereby logging the
    /// error and terminating the app with `fatalError`.
    ///
    /// If you implement `handleError(_:)` yourself, you may call this
    /// method at the end of your implementation.
    ///
    /// - Parameter error: The error that occurred.
    ///
    /// - See: `handleError(_:)`
    public static func handleErrorDefault(_ error: OrionHookError) -> Never {
        orionError("Error in tweak \(self): \(error)")
    }

    public static func handleError(_ error: OrionHookError) {
        handleErrorDefault(error)
    }

}

/// A tweak with a custom `Backend`.
///
/// The specified backend will override the one provided
/// via the Orion CLI.
public protocol TweakWithBackend: Tweak {

    /// The concrete type of the custom `Backend`.
    associatedtype BackendType: Backend

    /// The custom `Backend`.
    static var backend: BackendType { get }

}

extension TweakWithBackend {

    /// Activates the tweak. Do not call this yourself.
    ///
    /// :nodoc:
    public static func _activate(hooks: [_GlueAnyHook.Type]) {
        _activate(backend: backend, hooks: hooks)
    }

}

/// The default implementation of `Tweak`.
///
/// This type simply consists of an empty initializer.
public struct DefaultTweak: Tweak {
    public init() {}
}

#if SWIFT_PACKAGE
@available(*, unavailable, message: "orion_init should not be called when using Orion from SPM.")
public func orion_init() {}
#endif
