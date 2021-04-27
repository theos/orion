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
    private struct HookingError: LocalizedError, CustomStringConvertible {
        let description: String
        var errorDescription: String? { description }
        init(_ description: String) {
            self.description = description
        }
    }

    private func hookMethod(
        cls: AnyClass,
        sel: Selector,
        replacement: UnsafeMutableRawPointer
    ) throws -> UnsafeMutableRawPointer {
        guard let origMethod = class_getInstanceMethod(cls, sel) else {
            throw HookingError("Could not find method")
        }

        guard let types = method_getTypeEncoding(origMethod) else {
            throw HookingError("Could not get type encoding for method")
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

    public func apply(descriptors: [HookDescriptor]) {
        descriptors.forEach {
            switch $0 {
            case let .function(_, _, completion):
                completion(.failure(HookingError("""
                Could not hook function. The internal backend does not support function hooking."
                """)))
            case let .method(cls, sel, replacement, completion):
                completion(Result { try hookMethod(cls: cls, sel: sel, replacement: replacement) })
            }
        }
    }

}
