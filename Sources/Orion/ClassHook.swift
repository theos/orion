import Foundation

// marker protocol which sub-protocols can refine so that a user
// can't accidentally mark their FunctionHook as a SubclassedHook
// or something
public protocol _AnyClassHook: class, _AnyHook {}

public protocol _ClassHookProtocol: _AnyClassHook {
    associatedtype Target: AnyObject

    // protocols which should be added to the target class
    static var protocols: [Protocol] { get }

    var target: Target { get }

    init(target: Target)
}

extension _ClassHookProtocol {
    public static var protocols: [Protocol] { [] }
}

// A SubclassedHook is effectively just a ClassHook where we've added a new class pair on top
// of the original target. This protocol acts as an indicator that we need to do that. The
// subclass itself can be accessed via the static `target` property.
public protocol SubclassedHook: _AnyClassHook {
    // has default implementation
    static var subclassName: String { get }
}

public protocol _AnyClassHookWithComputedTarget: _AnyClassHook {
    static var _computedTarget: AnyClass { get }
}

// the target class to be hooked is computed via the `computedTarget` property
public protocol ClassHookWithComputedTarget: _AnyClassHookWithComputedTarget, _ClassHookProtocol {
    static var computedTarget: Target.Type { get }
}

// the target class is computed using the name `targetName`
public protocol ClassHookWithTargetName: ClassHookWithComputedTarget {
    static var targetName: String { get }
}

extension SubclassedHook {
    public static var subclassName: String {
        "OrionSubclass.\(NSStringFromClass(self))"
    }
}

extension ClassHookWithComputedTarget {
    public static var _computedTarget: AnyClass { computedTarget }
}

extension ClassHookWithTargetName {
    public static var computedTarget: Target.Type { Dynamic(targetName).as(type: Target.self) }
}

@objcMembers open class _ClassHookClass<Target: AnyObject> {
    public let target: Target
    public required init(target: Target) { self.target = target }
}

// we don't declare _ClassHookProtocol conformance on _ClassHookClass directly since that would
// result in _ClassHookClass inheriting the default implementations of hook[Will|Did]Activate,
// making it more complicated to allow those to be overridden
public typealias ClassHook<Target: AnyObject> = _ClassHookClass<Target> & _ClassHookProtocol

// the glue adds this as an extension on the user's own class because that ensures
// that, for example, if one has `class MySubclass: ClassHook<NSObject>, SubclassedHook`
// they can get the target with `MySubclass.target`. If this was part of _AnyGlueClassHook,
// accessing `target` on `MySubclass` directly would crash; you'd only be able to do it
// using Self inside a MySubclass method since that would refer to the concrete subclass.
public protocol _AnyClassHookWithInitializedTarget {
    static var initializedTarget: AnyClass { get }
}

extension _ClassHookProtocol {

    public static var target: Target.Type {
        guard let unwrapped = (self as? _AnyClassHookWithInitializedTarget.Type)?.initializedTarget as? Target.Type
            else { fatalError("Could not get target. Has the Orion glue file been compiled?") }
        return unwrapped
    }

    // since this may be expensive, rather than using a computed prop, when
    // accessing the static `target` this function is only called once and
    // then cached by the glue. Do not call this yourself.
    public static func _initializeTargetType() -> Target.Type {
        let baseTarget: Target.Type
        if let computed = self as? _AnyClassHookWithComputedTarget.Type {
            guard let _target = computed._computedTarget as? Target.Type
                else { fatalError("Conform to ClassHookWithComputedTarget") }
            baseTarget = _target
        } else {
            baseTarget = Target.self
        }

        let target: Target.Type
        if let subclassName = (self as? SubclassedHook.Type)?.subclassName {
            guard let pair: AnyClass = objc_allocateClassPair(baseTarget, subclassName, 0)
                else { fatalError("Could not allocate subclass for \(self)") }
            objc_registerClassPair(pair)
            guard let _target = pair as? Target.Type
                else { fatalError("Allocated invalid subclass for \(self)") }
            target = _target
        } else {
            target = baseTarget
        }

        protocols.forEach {
            guard class_addProtocol(target, $0)
                else { fatalError("Could not add protocol \($0) to \(target)") }
        }
        return target
    }

}

public protocol _AnyGlueClassHook: _AnyClassHook {
    static var _orig: AnyClass { get }
    var _orig: AnyObject { get }

    static var _supr: AnyClass { get }
    var _supr: AnyObject { get }
}

extension _ClassHookProtocol {

    // yes, thse can indeed be made computed properties (`var orig: Self`) instead,
    // but unfortunately the Swift compiler emits a warning when it sees an orig/supr
    // call like that, because it thinks it'll amount to infinite recursion

    @discardableResult
    public func orig<Result>(_ block: (Self) throws -> Result) rethrows -> Result {
        guard let unwrapped = (self as? _AnyGlueClassHook)?._orig as? Self
            else { fatalError("Could not get orig") }
        return try block(unwrapped)
    }

    @discardableResult
    public static func orig<Result>(_ block: (Self.Type) throws -> Result) rethrows -> Result {
        guard let unwrapped = (self as? _AnyGlueClassHook.Type)?._orig as? Self.Type
            else { fatalError("Could not get orig") }
        return try block(unwrapped)
    }

    @discardableResult
    public func supr<Result>(_ block: (Self) throws -> Result) rethrows -> Result {
        guard let unwrapped = (self as? _AnyGlueClassHook)?._supr as? Self
            else { fatalError("Could not get supr") }
        return try block(unwrapped)
    }

    @discardableResult
    public static func supr<Result>(_ block: (Self.Type) throws -> Result) rethrows -> Result {
        guard let unwrapped = (self as? _AnyGlueClassHook.Type)?._supr as? Self.Type
            else { fatalError("Could not get supr") }
        return try block(unwrapped)
    }

}

public struct ClassHookBuilder<Builder: HookBuilder> {
    let target: AnyClass
    var builder: Builder

    public mutating func addHook<Code>(
        _ sel: Selector,
        _ replacement: Code,
        isClassMethod: Bool,
        completion: @escaping (Code) -> Void
    ) {
        let cls: AnyClass = isClassMethod ? object_getClass(target)! : target
        builder.addMethodHook(
            cls: cls,
            sel: sel,
            replacement: unsafeBitCast(replacement, to: UnsafeMutableRawPointer.self)
        ) { orig in
            completion(unsafeBitCast(orig, to: Code.self))
        }
    }
}

public protocol _GlueClassHook: _AnyGlueClassHook, _ClassHookProtocol, _AnyGlueHook {
    associatedtype OrigType: _ClassHookProtocol where OrigType.Target == Target
    associatedtype SuprType: _ClassHookProtocol where SuprType.Target == Target

    static func activate<Builder: HookBuilder>(withClassHookBuilder builder: inout ClassHookBuilder<Builder>)
}

extension _GlueClassHook {
    public static var _orig: AnyClass { OrigType.self }
    public var _orig: AnyObject { OrigType(target: target) }

    public static var _supr: AnyClass { SuprType.self }
    public var _supr: AnyObject { SuprType(target: target) }

    public static func addMethod<Code>(_ selector: Selector, _ implementation: Code, isClassMethod: Bool) {
        let methodDescription = { "\(isClassMethod ? "+" : "-")[\(self) \(selector)]" }
        guard let method = (isClassMethod ? class_getClassMethod : class_getInstanceMethod)(self, selector)
            else { fatalError("Could not find method \(methodDescription())")}
        // TODO: Figure out if there's a way to get the type encoding statically instead
        guard let types = method_getTypeEncoding(method)
            else { fatalError("Could not get method signature for \(methodDescription())") }
        let cls: AnyClass = isClassMethod ? object_getClass(target)! : target
        guard class_addMethod(cls, selector, unsafeBitCast(implementation, to: IMP.self), types)
            else { fatalError("Failed to add method \(methodDescription())") }
    }

    public static func activate<Builder: HookBuilder>(withHookBuilder builder: inout Builder) {
        var classHookBuilder = ClassHookBuilder(target: target, builder: builder)
        defer { builder = classHookBuilder.builder }
        activate(withClassHookBuilder: &classHookBuilder)
    }
}
