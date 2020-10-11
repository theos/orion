import Foundation

public enum Function: CustomStringConvertible {
    case address(UnsafeMutableRawPointer)
    case symbol(_ name: String, image: URL?)

    // Equivalent to `.symbol(name, image: URL(fileURLWithPath: image)`.
    // This is a convenience. We don't allow `String?` since if you want to
    // pass `nil` you can use `symbol(_:String image:URL?)` with `URL?.none`.
    // Also allowing `String?` would result in disambiguation issues when passing
    // nil. If you already have a `String?`, either `if let` to handle nil separately,
    // or use something like `string.map(URL.init(fileURLWithPath:))` and then
    // call the `image: URL?` initializer.
    public static func symbol(_ name: String, image: String) -> Function {
        .symbol(name, image: URL(fileURLWithPath: image))
    }

    public var description: String {
        switch self {
        case let .address(address):
            return "\(address)"
        case let .symbol(name, image):
            return "\(image?.lastPathComponent ?? "<global>")`\(name)"
        }
    }
}

public protocol _FunctionHookProtocol: class, _AnyHook {
    static var target: Function { get }
    init()
}

open class _FunctionHookClass {
    required public init() {}
}

public typealias FunctionHook = _FunctionHookClass & _FunctionHookProtocol

public protocol _AnyGlueFunctionHook: _FunctionHookProtocol {
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

public protocol _GlueFunctionHook: _AnyGlueFunctionHook, _AnyGlueHook {
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
