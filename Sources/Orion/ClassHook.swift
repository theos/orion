import Foundation

public enum SubclassMode {
    case none
    case createSubclass
    case createSubclassNamed(String)

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

public protocol ClassHookProtocol: class, AnyHook {
    associatedtype Target: AnyObject

    /// The storage for the underlying target. Do not implement
    /// or use this yourself.
    ///
    /// :nodoc:
    static var _target: Target.Type { get }

    // The name of the target class (must be a subclass of `Target`), or
    // an empty string (the default) to use Target.self
    static var targetName: String { get }

    // If this is not .none, it indicates that this hook creates a subclass. In order to
    // achieve this, we add a new class pair on top of the original target. The subclass
    // itself can be accessed via the static `target` property. Defaults to .none.
    static var subclassMode: SubclassMode { get }

    // protocols which should be added to the target class. Defaults to an empty array.
    static var protocols: [Protocol] { get }

    var target: Target { get }

    init(target: Target)
}

extension ClassHookProtocol {

    public static var targetName: String { "" }

    public static var _target: Target.Type {
        fatalError("Could not get target. Has the Orion glue file been compiled?")
    }

    public static var subclassMode: SubclassMode { .none }

    public static var protocols: [Protocol] { [] }

}

@objcMembers open class ClassHookClass<Target: AnyObject> {
    public let target: Target
    public required init(target: Target) { self.target = target }
}

// we don't declare _ClassHookProtocol conformance on _ClassHookClass directly since that would
// result in _ClassHookClass inheriting the default implementations of _ClassHookProtocol and
// _AnyHook requirements, making it more difficult to override them
public typealias ClassHook<Target: AnyObject> = ClassHookClass<Target> & ClassHookProtocol

extension ClassHookProtocol {

    // this is in an extension so users can't accidentally override it
    public static var target: Target.Type { _target }

    /// Initializes the target. Do not call this yourself.
    ///
    /// Since this may be expensive, rather than using a computed prop, when
    /// accessing the static `target` this function is only called once and
    /// cached by the glue.
    ///
    /// :nodoc:
    public static func _initializeTargetType() -> Target.Type {
        let targetName = self.targetName // only call getter once
        let baseTarget = targetName.isEmpty ? Target.self : Dynamic(targetName).as(type: Target.self)

        let target: Target.Type
        if let subclassName = subclassMode.subclassName(withType: self) {
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

/// An existential for glue class hooks. Do not use this directly.
///
/// :nodoc:
public protocol _AnyGlueClassHook {
    static var _orig: AnyClass { get }
    var _orig: AnyObject { get }

    static var _supr: AnyClass { get }
    var _supr: AnyObject { get }
}

extension ClassHookProtocol {

    // @_transparent allows the compiler to incorporate these methods into the
    // control flow analysis of the caller. This means it sees the possibility
    // for the fatal errors, thereby not thinking that the function is infinitely
    // recursive which it would otherwise do (see https://bugs.swift.org/browse/SR-7925)
    // While that bug has technically been fixed, it still affects us because Swift
    // won't normally see the glue overrides and so it'll not realise that there is
    // an override point.

    // Note that we have to add a level of indirection to fatalError because otherwise
    // that code path isn't considered as part of the main control flow.

    @_transparent
    public var orig: Self {
        guard let unwrapped = (self as? _AnyGlueClassHook)?._orig as? Self
            else { _indirectFatalError("Could not get orig") }
        return unwrapped
    }

    @_transparent
    public static var orig: Self.Type {
        guard let unwrapped = (self as? _AnyGlueClassHook.Type)?._orig as? Self.Type
            else { _indirectFatalError("Could not get orig") }
        return unwrapped
    }

    @_transparent
    public var supr: Self {
        guard let unwrapped = (self as? _AnyGlueClassHook)?._supr as? Self
            else { _indirectFatalError("Could not get supr") }
        return unwrapped
    }

    @_transparent
    public static var supr: Self.Type {
        guard let unwrapped = (self as? _AnyGlueClassHook.Type)?._supr as? Self.Type
            else { _indirectFatalError("Could not get supr") }
        return unwrapped
    }

}

/// A helper type used in the glue file for applying class hooks. Do not
/// use this directly.
///
/// :nodoc:
public struct _ClassHookBuilder {
    let target: AnyClass

    var descriptors: [HookDescriptor] = []

    public mutating func addHook<Code>(
        _ sel: Selector,
        _ replacement: Code,
        isClassMethod: Bool,
        completion: @escaping (Code) -> Void
    ) {
        let cls: AnyClass = isClassMethod ? object_getClass(target)! : target
        descriptors.append(
            .method(cls: cls, sel: sel, replacement: unsafeBitCast(replacement, to: UnsafeMutableRawPointer.self)) {
                completion(unsafeBitCast($0, to: Code.self))
            }
        )
    }
}

/// A concrete class hook, implemented in the glue file. Do not use
/// this directly.
///
/// :nodoc:
public protocol _GlueClassHook: _AnyGlueClassHook, ClassHookProtocol, _AnyGlueHook {
    associatedtype OrigType: ClassHookProtocol where OrigType.Target == Target
    associatedtype SuprType: ClassHookProtocol where SuprType.Target == Target

    static func activate(withClassHookBuilder builder: inout _ClassHookBuilder)
}

/// :nodoc:
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

    public static func activate() -> [HookDescriptor] {
        var classHookBuilder = _ClassHookBuilder(target: target)
        activate(withClassHookBuilder: &classHookBuilder)
        return classHookBuilder.descriptors
    }
}
