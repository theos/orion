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

public protocol _FunctionHookProtocol: class, _AnyHook {
    static var target: Function { get }
    init()
}

open class _FunctionHookClass {
    required public init() {}
}

public typealias FunctionHook = _FunctionHookClass & _FunctionHookProtocol

public protocol _AnyGlueFunctionHook {
    static var _orig: AnyClass { get }
    var _orig: AnyObject { get }
}

extension _FunctionHookProtocol {
    @discardableResult
    public func orig<Result>(_ block: (Self) throws -> Result) rethrows -> Result {
        guard let unwrapped = (self as? _AnyGlueFunctionHook)?._orig as? Self
            else { fatalError("Could not get orig") }
        return try block(unwrapped)
    }
}

public protocol _GlueFunctionHook: _AnyGlueFunctionHook, _FunctionHookProtocol, _ConcreteHook {
    associatedtype Code
    static var origFunction: Code { get set }

    associatedtype OrigType: _FunctionHookProtocol
}

extension _GlueFunctionHook {
    public static func activate<Builder: HookBuilder>(withHookBuilder builder: inout Builder) {
        builder.addFunctionHook(target, replacement: unsafeBitCast(origFunction, to: UnsafeMutableRawPointer.self)) {
            origFunction = unsafeBitCast($0, to: Code.self)
        }
    }

    public static var _orig: AnyClass { OrigType.self }
    public var _orig: AnyObject { OrigType() }
}
