import Foundation

/// Internal storage associated with a `ClassHook`. Do not use this yourself.
///
/// :nodoc:
public final class _GlueClassHookStorage {
    let hookType: AnyClass
    @LazyAtomic private(set) var targetTypeOrError: Result<AnyObject.Type, Error>
    @LazyAtomic private(set) var group: HookGroup
    @LazyAtomic private(set) var targetType: AnyObject.Type

    // additional fields may be added here in the future

    init(
        hookType: AnyClass,
        loadTargetType: @escaping () -> Result<AnyObject.Type, Error>,
        loadGroup: @escaping () -> HookGroup
    ) {
        self.hookType = hookType
        _targetTypeOrError = LazyAtomic(wrappedValue: loadTargetType())
        _group = LazyAtomic(wrappedValue: loadGroup())
        // we need to finish initialization before we can use self
        // so start with a dummy value
        _targetType = LazyAtomic(wrappedValue: NSObject.self)
        _targetType = LazyAtomic(wrappedValue: {
            switch self.targetTypeOrError {
            case .success(let type):
                return type
            case .failure(let error):
                // we shouldn't get here because _GlueClassHook.activate(in:) should handle
                // failures gracefully - unless the user accesses HookType.target before that
                orionError("Could not get target type for ClassHook \(hookType): \(error)")
            }
        }())
    }
}

/// A placeholder class hook glue type. Do not use this yourself.
///
/// This type is the default value for the `ClassHookProtocol._Glue` constraint,
/// used to satisfy the compiler until the actual glue is provided.
///
/// :nodoc:
public enum _GlueClassHookPlaceholder: _GlueClassHook {
    public final class HookType: ClassHook<NSObject> {}
    public typealias OrigType = HookType
    public typealias SuprType = HookType

    public static var storage: _GlueClassHookStorage { error() }
    public static func activate(withClassHookBuilder builder: inout _GlueClassHookBuilder) { error() }

    private static func error() -> Never {
        orionError("Placeholder class hook used. Has the glue file been compiled?")
    }
}

/// A marker protocol to which `_GlueClassHook`'s orig/supr trampolines conform. Do
/// not use this yourself.
///
/// :nodoc:
public protocol _GlueClassHookTrampoline: ClassHookProtocol {}

/// A helper type used in the glue file for applying class hooks. Do not
/// use this directly.
///
/// :nodoc:
public struct _GlueClassHookBuilder {
    struct MethodAddition {
        let sel: Selector
        let imp: IMP
        let isClassMethod: Bool
    }

    let target: AnyClass
    let tweak: Tweak.Type

    var descriptors: [HookDescriptor] = []
    var methodAdditions: [MethodAddition] = []

    // completion may be called any number of times while during the duration of
    // the addHook call (including 0 times)
    public mutating func addHook<Code>(
        _ sel: Selector,
        _ replacement: Code,
        isClassMethod: Bool,
        completion: @escaping (Code) -> Void
    ) {
        let tweak = self.tweak
        let cls: AnyClass = isClassMethod ? object_getClass(target)! : target
        descriptors.append(
            .method(cls: cls, sel: sel, replacement: unsafeBitCast(replacement, to: UnsafeMutableRawPointer.self)) {
                switch $0 {
                case .success(let code):
                    completion(unsafeBitCast(code, to: Code.self))
                case .failure(let error):
                    tweak.handleError(
                        OrionHookError.methodHookFailed(
                            cls: cls,
                            sel: sel,
                            isClassMethod: isClassMethod,
                            underlying: error
                        )
                    )
                }
            }
        )
    }

    public mutating func addMethod<Code>(
        _ sel: Selector,
        _ imp: Code,
        isClassMethod: Bool
    ) {
        methodAdditions.append(
            MethodAddition(
                sel: sel,
                imp: unsafeBitCast(imp, to: IMP.self),
                isClassMethod: isClassMethod
            )
        )
    }
}

/// A concrete class hook, implemented in the glue file. Do not use
/// this directly.
///
/// :nodoc:
public protocol _GlueClassHook: _GlueAnyHook {
    associatedtype HookType: ClassHookProtocol
    associatedtype OrigType: ClassHookProtocol
    associatedtype SuprType: ClassHookProtocol

    static var storage: _GlueClassHookStorage { get }
    static func activate(withClassHookBuilder builder: inout _GlueClassHookBuilder)
}

/// :nodoc:
extension _GlueClassHook {
    // returns true iff success
    private static func addMethod(
        _ selector: Selector,
        _ implementation: IMP,
        isClassMethod: Bool
    ) throws {
        guard let method = (isClassMethod ? class_getClassMethod : class_getInstanceMethod)(HookType.self, selector),
              let types = method_getTypeEncoding(method)
        else { throw ClassHookError.addedMethodNotFound }
        let cls: AnyClass = isClassMethod ? object_getClass(HookType.target)! : HookType.target
        guard class_addMethod(cls, selector, implementation, types)
        else { throw ClassHookError.additionFailed }
    }

    public static func activate(in tweak: Tweak.Type) -> [HookDescriptor] {
        if case let .failure(error) = HookType._Glue.storage.targetTypeOrError {
            tweak.handleError(
                .targetClassNotAvailable(hookName: "\(HookType.self)", underlying: error)
            )
            return []
        }
        var classHookBuilder = _GlueClassHookBuilder(target: HookType.target, tweak: tweak)
        activate(withClassHookBuilder: &classHookBuilder)
        for addition in classHookBuilder.methodAdditions {
            do {
                try addMethod(addition.sel, addition.imp, isClassMethod: addition.isClassMethod)
            } catch {
                tweak.handleError(
                    OrionHookError.methodAdditionFailed(
                        cls: HookType.target,
                        sel: addition.sel,
                        isClassMethod: addition.isClassMethod,
                        underlying: error
                    )
                )
            }
        }
        return classHookBuilder.descriptors
    }

    public static var groupType: HookGroup.Type {
        HookType.Group.self
    }

    public static func hookWillActivate() -> Bool {
        HookType.hookWillActivate()
    }

    public static func hookDidActivate() {
        HookType.hookDidActivate()
    }

    public static func initializeStorage() -> _GlueClassHookStorage {
        // this gives us the type of the user's hook rather than
        // our concrete subclass
        _GlueClassHookStorage(
            hookType: HookType.self,
            loadTargetType: { Result(catching: HookType.initializeTargetType) },
            loadGroup: HookType.loadGroup
        )
    }
}

extension SubclassMode {
    fileprivate func subclassName(withType type: AnyClass) -> String? {
        switch self {
        case .none:
            return nil
        case .createSubclass:
            return "OrionSubclass.\(NSStringFromClass(type))"
        case .createSubclassNamed(let name):
            return name
        }
    }
}

/// :nodoc:
extension ClassHookProtocol {
    // since `target` is referred to in `activate()`, this will deterministically be called
    // when a class hook is activated.
    fileprivate static func initializeTargetType() throws -> Target.Type {
        let targetName = self.targetName // only call getter once
        let baseTarget: Target.Type
        if targetName.isEmpty {
            baseTarget = Target.self
        } else {
            guard let cls = NSClassFromString(targetName) else {
                throw ClassHookError.targetNotFound
            }
            guard let typed = cls as? Target.Type else {
                throw ClassHookError.targetHasIncompatibleType(expected: Target.self, found: cls)
            }
            baseTarget = typed
        }

        let target: Target.Type
        if let subclassName = subclassMode.subclassName(withType: _Glue.storage.hookType) {
            guard let pair: AnyClass = objc_allocateClassPair(baseTarget, subclassName, 0)
                else { throw ClassHookError.subclassCreationFailed }
            objc_registerClassPair(pair)
            guard let _target = pair as? Target.Type
                else { throw ClassHookError.subclassCreationFailed }
            target = _target
        } else {
            target = baseTarget
        }

        try protocols.forEach {
            guard class_addProtocol(target, $0)
                else { throw ClassHookError.protocolAdditionFailed }
        }
        return target
    }
}
