import Foundation

/// An enumeration describing a function.
public enum Function: CustomStringConvertible {

    /// A function referred to by its address.
    case address(UnsafeMutableRawPointer)

    /// A function referred to by its name and (optionally) image.
    ///
    /// If `image` is `nil`, it implies that the function may be
    /// in any image.
    case symbol(_ name: String, image: URL?)

    /// Equivalent to `.symbol(name, image: URL(fileURLWithPath: image))`
    ///
    /// This initializer deliberately requires a non-nil `image` parameter, because
    /// allowing `nil` would cause ambiguity between this method and the enum case
    /// when passed `nil` as the second parameter. To use a `nil` image, invoke
    /// `symbol(_:String image:URL?)` instead, passing `URL?.none`.
    ///
    /// - Parameter name: The name of the symbol.
    ///
    /// - Parameter image: The path to the image in which the symbol is located.
    ///
    /// - Returns: The described `Function`.
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

/// The protocol to which function hooks conform. Do not conform to this
/// directly; use `FunctionHook`.
public protocol FunctionHookProtocol: AnyObject, AnyHook {

    /// The glue type associated with this hook. Do not implement or use
    /// this yourself.
    ///
    /// - See: `_GlueAnyHook`
    ///
    /// :nodoc:
    associatedtype _Glue: _GlueFunctionHook = _GlueFunctionHookPlaceholder

    /// The function which is to be hooked.
    static var target: Function { get }

    /// Initialize the function hook type. Do not invoke or override this;
    /// use `AnyHook.hookWillActivate()` or `AnyHook.hookDidActivate()` for
    /// lifecycle events.
    init()

}

/// The class which all function hooks inherit from. Do not subclass
/// this directly; use `FunctionHook`.
///
/// :nodoc:
open class _FunctionHookClass {

    /// Initialize the function hook type. Do not invoke or override this;
    /// use `AnyHook.hookWillActivate()` or `AnyHook.hookDidActivate()` for
    /// lifecycle events.
    required public init() {}

}

/// The base function hook type. All function hooks must subclass this.
///
/// In order to make a function hook, create a class which conforms
/// to this type. Satisfy the protocol requirement by providing a
/// static `target` property, and declare a function named `function`
/// with the signature of the function that is being hooked.
///
/// The original function implementation can be accessed via `orig.function`.
///
/// # Example
///
/// The following example hooks the C standard library function `atoi` such
/// that `atoi("1234")` returns `4321` and all other calls behave normally.
///
/// ```
/// class AtoiHook: FunctionHook {
///     static let target = Function.symbol("atoi", image: nil)
///
///     func function(_ string: UnsafePointer<Int8>) -> Int32 {
///         if String(cString: string) == "1234" {
///             return 4321
///         } else {
///             return orig.function(string)
///         }
///     }
/// }
/// ```
public typealias FunctionHook = FunctionHookProtocol & _FunctionHookClass

extension FunctionHookProtocol {

    /// A proxy which allows invoking the original function.
    ///
    /// Use `orig.function` to access the original implementation of the hooked
    /// function.
    ///
    /// See the example in the documentation of `FunctionHook` for more
    /// information on how this is used.
    @_transparent
    public var orig: Self {
        disableRecursionCheck()
        guard let unwrapped = _Glue.OrigType() as? Self
            else { orionError("Could not get orig") }
        return unwrapped
    }

}

/// :nodoc:
extension FunctionHookProtocol {
    public static var group: Group {
        guard let group = _Glue.storage.group as? Group else {
            orionError("Got unexpected group type for \(self)")
        }
        return group
    }
}
