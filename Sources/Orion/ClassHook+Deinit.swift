import Foundation
#if SWIFT_PACKAGE
@_implementationOnly import OrionC
#else
@_implementationOnly import Orion.Private
#endif

/// The action to perform after a `ClassHookProtocol.deinitializer()` is run.
///
/// Unless you're managing the target class' own resources, you usually want
/// to use `callOrig`.
public enum DeinitPolicy {
    /// Call the target's original deinitializer implementation.
    case callOrig
    /// Call the target's superclass deinitializer implementation.
    case callSupr
}

/// :nodoc:
extension _GlueClassHookBuilder {
    private static let deallocSelector = NSSelectorFromString("dealloc")

    public typealias Deinitializer = @convention(c) (Any, Selector) -> Void

    // for some reason using `@escaping Deinitializer` instead of `Code`
    // works in SPM but not with the binary framework (maybe a swiftinterface
    // bug or library evolution thing?)
    public mutating func addDeinitializer<T: ClassHookProtocol, Code>(
        to classHook: T.Type,
        getOrig: @escaping () -> Deinitializer,
        setOrig: @escaping (Code) -> Void
    ) {
        // although arguments are +0 in recent Swift versions, we use
        // Unmanaged anyway for semantic correctness. This ensures that
        // the object isn't automatically retained before the orig/supr
        // dealloc is called.
        let imp = imp_implementationWithBlock({ target in
            // we use an autorelease pool here to ensure that `target`
            // remains at +0 going into the orig/supr deinit call
            let policy: DeinitPolicy = autoreleasepool {
                let value = target.takeUnretainedValue()
                guard let castTarget = value as? T.Target else {
                    orionError("""
                    Could not convert value of type \(type(of: value)) to expected \
                    type \(classHook.target)
                    """)
                }
                return classHook.init(target: castTarget).deinitializer()
            }
            withUnsafePointer(to: target) {
                switch policy {
                case .callOrig:
                    _orion_call_dealloc(getOrig(), $0, Self.deallocSelector)
                case .callSupr:
                    _orion_call_super_dealloc(classHook.target, $0, Self.deallocSelector)
                }
            }
        } as @convention(block) (Unmanaged<AnyObject>) -> Void)
        let method = unsafeBitCast(imp, to: Code.self)
        addHook(Self.deallocSelector, method, isClassMethod: false, completion: setOrig)
    }
}

/// :nodoc:
extension _GlueClassHookTrampoline {
    public func deinitOrigError(file: StaticString = #file, line: UInt = #line) -> Never {
        orionError("Do not call `orig.deinitializer()`.", file: file, line: line)
    }

    public func deinitSuprError(file: StaticString = #file, line: UInt = #line) -> Never {
        orionError("Do not call `supr.deinitializer()`.", file: file, line: line)
    }

    public func trampOrigError(file: StaticString = #file, line: UInt = #line) -> Never {
        orionError("Attempted to call orig on a supr_tramp method.", file: file, line: line)
    }
}
