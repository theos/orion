import Foundation

public struct Function: CustomStringConvertible {
    public enum Descriptor: CustomStringConvertible {
        case address(UnsafeMutableRawPointer)
        case symbol(image: URL?, name: String)

        public var description: String {
            switch self {
            case let .address(address):
                return "\(address)"
            case let .symbol(image, name):
                return "\(image?.lastPathComponent ?? "<global>")`\(name)"
            }
        }
    }

    public let descriptor: Descriptor

    public init(address: UnsafeMutableRawPointer) {
        self.descriptor = .address(address)
    }

    public init(image: URL?, name: String) {
        self.descriptor = .symbol(image: image, name: name)
    }

    public var description: String { descriptor.description }
}

public protocol _FunctionHookProtocol: class, AnyHook {
    static var target: Function { get }
    init()
}
extension _FunctionHookProtocol {
    public static func activate(withBackend backend: Backend) {
        fatalError("\(type(of: self)) is not a concrete function hook")
    }
}

open class _FunctionHookClass {
    required public init() {}
}

public typealias FunctionHook = _FunctionHookClass & _FunctionHookProtocol

public protocol _ConcreteFunctionHook: ConcreteHook {
    static var _orig: AnyClass { get }
    var _orig: AnyObject { get }
}

extension _FunctionHookProtocol {
    @discardableResult
    public func orig<Result>(_ block: (Self) throws -> Result) rethrows -> Result {
        guard let unwrapped = (self as? _ConcreteFunctionHook)?._orig as? Self
            else { fatalError("Could not get orig") }
        return try block(unwrapped)
    }
}

public protocol ConcreteFunctionHook: _ConcreteFunctionHook, _FunctionHookProtocol {
    associatedtype Code
    static var origFunction: Code { get set }

    associatedtype OrigType: _FunctionHookProtocol
}

extension ConcreteFunctionHook {
    public static func activate(withHooker hooker: inout Hooker) {
        hooker.addFunctionHook(target, replacement: origFunction) { origFunction = $0 }
    }

    public static var _orig: AnyClass { OrigType.self }
    public var _orig: AnyObject { OrigType() }
}
