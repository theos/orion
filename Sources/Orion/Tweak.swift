import Foundation
#if SWIFT_PACKAGE
import OrionC
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
    /// Use this method to perform any custom initialization behavior.
    ///
    /// - Warning: This method is called at launch time, even before `main`
    /// has been invoked. Do not synchronously perform any time-consuming
    /// tasks here, because they will make the target process launch slowly.
    init()

    /// Called after all of the tweak's hooks have been activated. The
    /// default implementation does nothing.
    func tweakDidActivate()

}

extension Tweak {

    /// Activates the tweak. Do not call this yourself.
    public func activate<BackendType: Backend>(backend: BackendType, hooks: [_AnyGlueHook.Type]) {
        #if SWIFT_PACKAGE
        // this is effectively a no-op but we need it in order to prevent the
        // compiler from stripping out the constructor because it doesn't see
        // it being used
        _orion_init_c()
        #endif

        // this filters out hooks that return false from willActivate
        let hooksWithDescriptors = hooks.compactMap { hook in
            hook.activateIfNeeded().map { (hook, $0) }
        }

        backend.apply(hooks: hooksWithDescriptors.flatMap { $0.1 })

        hooksWithDescriptors.forEach { $0.0.hookDidActivate() }

        tweakDidActivate()
    }

    public func tweakDidActivate() {}

}

/// A tweak with a custom `Backend`.
///
/// The specified backend will override the one provided
/// via the Orion CLI.
public protocol TweakWithBackend: Tweak {

    /// The concrete type of the custom `Backend`.
    associatedtype BackendType: Backend

    /// The custom `Backend`.
    var backend: BackendType { get }

}

extension TweakWithBackend {

    /// Activates the tweak. Do not call this yourself.
    public func activate(hooks: [_AnyGlueHook.Type]) {
        activate(backend: backend, hooks: hooks)
    }

}

/// The default implementation of `Tweak`.
///
/// This type has no special behavior.
public struct DefaultTweak: Tweak {
    public init() {}
}
