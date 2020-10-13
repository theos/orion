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

public protocol _ClassHookProtocol: class, _AnyHook {
    associatedtype Target: AnyObject

    // Do not implement this yourself
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

extension _ClassHookProtocol {

    public static var targetName: String { "" }

    public static var _target: Target.Type {
        fatalError("Could not get target. Has the Orion glue file been compiled?")
    }

    public static var subclassMode: SubclassMode { .none }

    public static var protocols: [Protocol] { [] }

}

@objcMembers open class _ClassHookClass<Target: AnyObject> {
    public let target: Target
    public required init(target: Target) { self.target = target }
}

// we don't declare _ClassHookProtocol conformance on _ClassHookClass directly since that would
// result in _ClassHookClass inheriting the default implementations of _ClassHookProtocol and
// _AnyHook requirements, making it more difficult to override them
public typealias ClassHook<Target: AnyObject> = _ClassHookClass<Target> & _ClassHookProtocol

extension _ClassHookProtocol {

    // this is in an extension so users can't accidentally override it
    public static var target: Target.Type { _target }

    // since this may be expensive, rather than using a computed prop, when
    // accessing the static `target` this function is only called once and
    // then cached by the glue. Do not call this yourself.
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

public protocol _AnyGlueClassHook {
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
