import Foundation

public protocol _ClassHookProtocol: AnyHook {
    associatedtype Target: AnyObject

    static var target: Target.Type { get }
    var target: Target { get }

    init(target: Target)
}

open class ClassHook<Target: AnyObject>: _ClassHookProtocol {
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

public enum ClassRequest {
    case origCall
    case superCall
}

public protocol ConcreteClassHook: ConcreteHook {
    static var callState: CallState<ClassRequest> { get }
    var callState: CallState<ClassRequest> { get }
}

extension _ClassHookProtocol {
    private func makeRequest<Result>(
        _ request: ClassRequest,
        transition: CallStateTransition,
        _ block: () throws -> Result
    ) rethrows -> Result {
        guard let concrete = self as? ConcreteClassHook else {
            fatalError("\(type(of: self)) is not a concrete function hook")
        }
        concrete.callState.makeRequest(request, transition: transition)
        return try block()
    }

    private static func makeRequest<Result>(
        _ request: ClassRequest,
        transition: CallStateTransition,
        _ block: () throws -> Result
    ) rethrows -> Result {
        guard let concrete = self as? ConcreteClassHook.Type else {
            fatalError("\(self) is not a concrete function hook")
        }
        concrete.callState.makeRequest(request, transition: transition)
        return try block()
    }

    @discardableResult
    public func orig<Result>(
        transition: CallStateTransition = .default,
        _ block: () throws -> Result
    ) rethrows -> Result {
        try makeRequest(.origCall, transition: transition, block)
    }

    @discardableResult
    public static func orig<Result>(
        transition: CallStateTransition = .default,
        _ block: () throws -> Result
    ) rethrows -> Result {
        try makeRequest(.origCall, transition: transition, block)
    }

    @discardableResult
    public func supr<Result>(
        transition: CallStateTransition = .default,
        _ block: () throws -> Result
    ) rethrows -> Result {
        try makeRequest(.superCall, transition: transition, block)
    }

    @discardableResult
    public static func supr<Result>(
        transition: CallStateTransition = .default,
        _ block: () throws -> Result
    ) rethrows -> Result {
        try makeRequest(.superCall, transition: transition, block)
    }
}

extension _ClassHookProtocol where Self: ConcreteClassHook {
    public static func register<Code>(_ backend: Backend, _ sel: Selector, _ replacement: inout Code, isClassMethod: Bool = false) {
        let cls: AnyClass = isClassMethod ? object_getClass(Self.target)! : Self.target
        replacement = backend.hookMethod(cls: cls, sel: sel, replacement: replacement)
    }
}
