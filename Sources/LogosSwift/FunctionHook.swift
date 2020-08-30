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

public protocol FunctionHook: class, AnyHook {
    static var target: Function { get }
}
extension FunctionHook {
    public static func activate(withBackend backend: Backend) {
        fatalError("\(type(of: self)) is not a concrete function hook")
    }
}

public enum FunctionRequest {
    case origCall
}

public protocol _ConcreteFunctionHook: ConcreteHook {
    var callState: CallState<FunctionRequest> { get }
}

extension FunctionHook {
    public func orig<Result>(
        transition: CallStateTransition = .default,
        _ block: () throws -> Result
    ) rethrows -> Result {
        guard let concrete = self as? _ConcreteFunctionHook else {
            fatalError("\(type(of: self)) is not a concrete function hook")
        }
        concrete.callState.makeRequest(.origCall, transition: transition)
        return try block()
    }
}

public protocol ConcreteFunctionHook: _ConcreteFunctionHook, FunctionHook {
    associatedtype Code
    static var origFunction: Code { get set }
}
extension ConcreteFunctionHook {
    public static func activate(withBackend backend: Backend) {
        origFunction = backend.hookFunction(target, replacement: origFunction)
    }
}
