import Foundation

/// Internal storage associated with a `ClassHook`. Do not use this yourself.
///
/// :nodoc:
public final class _GlueClassHookStorage {
    let hookType: AnyClass
    @LazyAtomic private(set) var targetType: AnyObject.Type
    @LazyAtomic private(set) var group: HookGroup

    // additional fields may be added here in the future

    init(
        hookType: AnyClass,
        loadTargetType: @escaping () -> AnyObject.Type,
        loadGroup: @escaping () -> HookGroup
    ) {
        self.hookType = hookType
        _targetType = LazyAtomic(wrappedValue: loadTargetType())
        _group = LazyAtomic(wrappedValue: loadGroup())
    }
}

/// A placeholder class hook glue type. Do not use this yourself.
///
/// This type is the default value for the `ClassHookProtocol._Glue` constraint,
/// used to satisfy the compiler until the actual glue is provided.
///
/// :nodoc:
public enum _GlueClassHookPlaceholder: _GlueClassHook {
    public class HookType: ClassHook<NSObject> {}
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
    let target: AnyClass

    var descriptors: [HookDescriptor] = []

    public mutating func addHook<Code>(
        _ sel: Selector,
        _ replacement: Code,
        isClassMethod: Bool,
        saveOrig: @escaping (Code) -> Void
    ) {
        let cls: AnyClass = isClassMethod ? object_getClass(target)! : target
        descriptors.append(
            .method(cls: cls, sel: sel, replacement: unsafeBitCast(replacement, to: UnsafeMutableRawPointer.self)) {
                saveOrig(unsafeBitCast($0, to: Code.self))
            }
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
    public static func addMethod<Code>(_ selector: Selector, _ implementation: Code, isClassMethod: Bool) {
        let methodDescription = { "\(isClassMethod ? "+" : "-")[\(self) \(selector)]" }
        guard let method = (isClassMethod ? class_getClassMethod : class_getInstanceMethod)(HookType.self, selector)
            else { orionError("Could not find method \(methodDescription())") }
        guard let types = method_getTypeEncoding(method)
            else { orionError("Could not get method signature for \(methodDescription())") }
        let cls: AnyClass = isClassMethod ? object_getClass(HookType.target)! : HookType.target
        guard class_addMethod(cls, selector, unsafeBitCast(implementation, to: IMP.self), types)
            else { orionError("Failed to add method \(methodDescription())") }
    }

    public static func activate() -> [HookDescriptor] {
        var classHookBuilder = _GlueClassHookBuilder(target: HookType.target)
        activate(withClassHookBuilder: &classHookBuilder)
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
            loadTargetType: HookType.initializeTargetType,
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
    fileprivate static func initializeTargetType() -> Target.Type {
        let targetName = self.targetName // only call getter once
        let baseTarget = targetName.isEmpty ? Target.self : Dynamic(targetName).as(type: Target.self)

        let target: Target.Type
        if let subclassName = subclassMode.subclassName(withType: _Glue.storage.hookType) {
            guard let pair: AnyClass = objc_allocateClassPair(baseTarget, subclassName, 0)
                else { orionError("Could not allocate subclass for \(self)") }
            objc_registerClassPair(pair)
            guard let _target = pair as? Target.Type
                else { orionError("Allocated invalid subclass for \(self)") }
            target = _target
        } else {
            target = baseTarget
        }

        protocols.forEach {
            guard class_addProtocol(target, $0)
                else { orionError("Could not add protocol \($0) to \(target)") }
        }
        return target
    }
}
