import Foundation

public protocol _ClassHookProtocol: class, AnyHook {
    associatedtype Target: AnyObject

    static var target: Target.Type { get }
    var target: Target { get }

    init(target: Target)
}

@objcMembers open class ClassHook<Target: AnyObject>: _ClassHookProtocol {
    open var target: Target
    public required init(target: Target) { self.target = target }

    public class var target: Target.Type { Target.self }
}

public protocol _NamedClassHookProtocol {
    static var targetName: String { get }
}

open class _NamedClassHookClass<Target: AnyObject>: ClassHook<Target> {
    public override class var target: Target.Type {
        guard let targetName = (self as? _NamedClassHookProtocol.Type)?.targetName else {
            fatalError("Must conform to NamedClassHookProtocol when conforming to NamedClassHookClass")
        }
        guard let cls = NSClassFromString(targetName) else {
            fatalError("Could not find a class named '\(targetName)'")
        }
        guard let typedClass = cls as? Target.Type else {
            fatalError("The class '\(targetName)' is not a subclass of \(Target.self)")
        }
        return typedClass
    }
}

public typealias NamedClassHook<Target: AnyObject> = _NamedClassHookClass<Target> & _NamedClassHookProtocol

public protocol _ConcreteClassHook: ConcreteHook {
    static var _orig: AnyClass { get }
    var _orig: AnyObject { get }

    static var _supr: AnyClass { get }
    var _supr: AnyObject { get }
}

extension _ClassHookProtocol {

    @discardableResult
    public func orig<Result>(_ block: (Self) throws -> Result) rethrows -> Result {
        guard let unwrapped = (self as? _ConcreteClassHook)?._orig as? Self
            else { fatalError("Could not get orig") }
        return try block(unwrapped)
    }

    @discardableResult
    public static func orig<Result>(_ block: (Self.Type) throws -> Result) rethrows -> Result {
        guard let unwrapped = (self as? _ConcreteClassHook.Type)?._orig as? Self.Type
            else { fatalError("Could not get orig") }
        return try block(unwrapped)
    }

    @discardableResult
    public func supr<Result>(_ block: (Self) throws -> Result) rethrows -> Result {
        guard let unwrapped = (self as? _ConcreteClassHook)?._supr as? Self
            else { fatalError("Could not get supr") }
        return try block(unwrapped)
    }

    @discardableResult
    public static func supr<Result>(_ block: (Self.Type) throws -> Result) rethrows -> Result {
        guard let unwrapped = (self as? _ConcreteClassHook.Type)?._supr as? Self.Type
            else { fatalError("Could not get supr") }
        return try block(unwrapped)
    }

}

public protocol ConcreteClassHook: _ConcreteClassHook, _ClassHookProtocol {
    associatedtype OrigType: _ClassHookProtocol where OrigType.Target == Target
    associatedtype SuprType: _ClassHookProtocol where SuprType.Target == Target
}
extension ConcreteClassHook {
    public static var _orig: AnyClass { OrigType.self }
    public var _orig: AnyObject { OrigType(target: target) }

    public static var _supr: AnyClass { SuprType.self }
    public var _supr: AnyObject { SuprType(target: target) }

    public static func register<Code>(_ backend: Backend, _ sel: Selector, _ replacement: inout Code, isClassMethod: Bool = false) {
        let cls: AnyClass = isClassMethod ? object_getClass(Self.target)! : Self.target
        replacement = backend.hookMethod(cls: cls, sel: sel, replacement: replacement)
    }
}
