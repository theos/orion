import Foundation

extension Backends {

    /// The internal backend.
    ///
    /// This backend uses Objective-C runtime functions ("swizzling")
    /// to apply method hooks.
    ///
    /// - Warning: This backend does not support function hooking.
    public struct Internal: DefaultBackend {
        public init() {}
    }

}

extension Backends.Internal {

    private func hookMethod(
        cls: AnyClass,
        sel: Selector,
        replacement: UnsafeMutableRawPointer
    ) -> UnsafeMutableRawPointer {
        let methodDescription = { "\(class_isMetaClass(cls) ? "+" : "-")[\(cls) \(sel)]" }

        guard let origMethod = class_getInstanceMethod(cls, sel) else {
            orionError("Could not find method \(methodDescription())")
        }

        guard let types = method_getTypeEncoding(origMethod) else {
            orionError("Could not get type encoding for method \(methodDescription())")
        }

        let imp = IMP(replacement)
        let orig: IMP
        // first try to add the method (in case the current imp is inherited)
        if class_addMethod(cls, sel, imp, types) {
            // if added, return the super imp
            orig = method_getImplementation(origMethod)
        } else {
            // otherwise, the current class has its own imp of the method. Replace it.
            orig = method_setImplementation(origMethod, imp)
        }

        return .init(orig)
    }

    public func apply(hooks: [HookDescriptor]) {
        hooks.forEach {
            switch $0 {
            case .function(let function, _, _):
                orionError(
                    "Could not hook \(function). The internal backend does not support function hooking"
                )
            case let .method(cls, sel, replacement, completion):
                completion(hookMethod(cls: cls, sel: sel, replacement: replacement))
            }
        }
    }

}
