import Foundation
#if SWIFT_PACKAGE
import OrionC
#endif

public protocol Tweak {
    init()
    func tweakDidActivate()
}

extension Tweak {
    public func activate<BackendType: Backend>(backend: BackendType, hooks: [_AnyGlueHook.Type]) {
        #if SWIFT_PACKAGE
        // this is effectively a no-op but we need it in order to prevent the
        // compiler from stripping out the constructor because it doesn't see
        // it being used
        __orion_constructor_c()
        #endif

        backend.hook { builder in
            for hook in hooks {
                hook.activateIfNeeded(withHookBuilder: &builder)
            }
        }

        tweakDidActivate()
    }

    public func tweakDidActivate() {}
}

// a tweak which forces a custom backend
public protocol TweakWithBackend: Tweak {
    associatedtype BackendType: Backend
    var backend: BackendType { get }
}

extension TweakWithBackend {
    public func activate(hooks: [_AnyGlueHook.Type]) {
        activate(backend: backend, hooks: hooks)
    }
}

public struct DefaultTweak: Tweak {
    public init() {}
}
