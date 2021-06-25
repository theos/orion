import Foundation

/// An enumeration describing a `ClassHook`'s subclassing behavior.
public enum SubclassMode {

    /// Do not create a subclass for this hook.
    case none

    /// Create a subclass with a name derived from the hook name.
    case createSubclass

    /// Create a subclass with the provided name.
    case createSubclassNamed(String)

}

/// The protocol to which class hooks conform. Do not conform to this
/// directly; use `ClassHook`.
public protocol ClassHookProtocol: AnyObject, AnyHook {

    /// The type of the target. Specify this via the generic argument on
    /// `ClassHook`.
    ///
    /// This type must be either the target's own class or a class in
    /// its inheritance chain.
    associatedtype Target: AnyObject

    /// The glue type associated with this hook. Do not implement or use
    /// this yourself.
    ///
    /// - See: `_GlueAnyHook`
    ///
    /// :nodoc:
    associatedtype _Glue: _GlueClassHook = _GlueClassHookPlaceholder

    /// The name of the target class, or the empty string to use `Target.self`.
    ///
    /// This class must be `Target` or a subclass of `Target`. Defaults to
    /// an empty string.
    ///
    /// - Warning: Do not attempt to access `target` in the getter for this property,
    /// as that will lead to infinite recursion.
    static var targetName: String { get }

    /// If this is not `.none`, it indicates that this hook creates a subclass.
    ///
    /// The created subclass can be accessed via the static `target` property. The
    /// default value is `.none`.
    ///
    /// This property is implemented by creating a new class pair on top of the
    /// original target, when the property is not `.none`.
    ///
    /// - Warning: Do not attempt to access `target` in the getter for this property,
    /// as that will lead to infinite recursion.
    static var subclassMode: SubclassMode { get }

    /// An array of protocols which should be added to the target class.
    ///
    /// The default value is an empty array.
    ///
    /// - Warning: Do not attempt to access `target` in the getter for this property,
    /// as that will lead to infinite recursion.
    static var protocols: [Protocol] { get }

    /// The current instance of the hooked class, upon which a hooked method
    /// has been called.
    ///
    /// - Warning: Do not attempt to implement this yourself; use the default
    /// implementation.
    var target: Target { get }

    /// Initializes the type with the provided target instance. Do not override this.
    init(target: Target)

    /// A function which is run before a `target` is deallocated.
    ///
    /// Use this to perform any cleanup before the target is deallocated.
    ///
    /// The default implementation is equivalent to simply returning
    /// `DeinitPolicy.callOrig`.
    ///
    /// - Important: You **must not** call `orig.deinitializer()` or
    /// `supr.deinitializer()` in this method. Instead, return the
    /// appropriate deinit policy.
    ///
    /// - Returns: A `DeinitPolicy` representing the action to perform next.
    func deinitializer() -> DeinitPolicy

}

/// :nodoc:
extension ClassHookProtocol {

    public static var targetName: String { "" }

    public static var subclassMode: SubclassMode { .none }

    public static var protocols: [Protocol] { [] }

    public func deinitializer() -> DeinitPolicy { .callOrig }

}

/// The class which all class hooks inherit from. Do not subclass
/// this directly; use `ClassHook`.
///
/// :nodoc:
@objcMembers open class _ClassHookClass<Target: AnyObject> {

    /// The current instance of the hooked class, upon which a hooked method
    /// has been called.
    public let target: Target

    /// Initializes the type with the provided target instance. Do not override this.
    public required init(target: Target) { self.target = target }

}

// swiftlint:disable line_length
/// The base class hook type. All class hooks must subclass this.
///
/// This type allows hooking methods of a chosen target class. For
/// a detailed description of all available configuration options,
/// see `ClassHookProtocol`.
///
/// # Specifying a Target Class
///
/// In order to hook a class which is known by the Swift compiler at
/// compile-time, specialize `ClassHook` with that class as the `Target`
/// type. For example, to hook `MyClass` one could declare
/// `class MyHook: ClassHook<MyClass>`.
///
/// In order to hook a class which is not known by the Swift compiler
/// at compile-time, specify a class in its inheritance chain as `Target`
/// (you can use `NSObject` if no class which is more specific is available
/// at compile-time), and provide the actual target class' name by implementing
/// the static `targetName` property.
///
/// # Hooking Methods
///
/// ## Instance/Class Methods
///
/// To hook an instance method on the target class, simply declare an instance
/// method with the same name and method signature in your hook class. The
/// contents of your method will replace the original method implementation.
///
/// In order to hook a class method, declare the replacement method as a `class`
/// method.
///
/// In either case, the method must not be `final` or `static`. Methods which have
/// a visibility of `fileprivate` or `private` will be ignored by Orion and can
/// thus be used as helper methods.
///
/// Methods which have an Objective-C selector that begins with `alloc`, `new`,
/// `copy`, or `mutableCopy`, follow the appropriate Objective-C conventions
/// described [here](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/Articles/mmRules.html).
/// In the rare case that you need to manually override this behavior,
/// add `// orion:returns_retained true` (or `false`) above your method
/// declaration. These directives behave like `NS_RETURNS_RETAINED` and
/// `NS_RETURNS_NOT_RETAINED` respectively.
///
/// ## Accessing Target Information
///
/// Within a method hook function, the object upon which the hooked method was
/// invoked can be accessed via `target`. To call the original implementation
/// of the method, call the method itself on the `orig` proxy. Similarly, the
/// superclass implementation can be accessed via the `supr` proxy.
///
/// ## Method Naming
///
/// To figure out the required Swift name for an Objective-C method, you may want
/// to follow the way that Objective-C APIs are [renamed](https://github.com/apple/swift-evolution/blob/main/proposals/0005-objective-c-name-translation.md)
/// when they are imported into Swift, in reverse. If you cannot figure out the
/// Swift name for the method, you can also provide the Objective-C selector name
/// directly by declaring the function as `@objc(selector:name:) func`.
///
/// ## Initializers
///
/// In order to hook an initializer with Orion, declare an _instance_ method with
/// the initializer's name and Objective-C method signature, with a return type of
/// `Target`. For example `func initWithFrame(_ frame: CGRect) -> Target`. Inside
/// the method, your first statement should be a call to an initializer on `supr`
/// or `orig`, after which you can configure `target` as you desire before you
/// return it. To hook `NSObject.init`, use backticks to escape the init keyword:
/// ```
/// func `init`() -> Target.
/// ```
///
/// Example of hooking `initWithFrame`:
/// ```
/// class ViewHook: ClassHook<UIView> {
///     func initWithFrame(_ frame: CGRect) -> Target {
///         let target = orig.initWithFrame(frame)
///         // configure target
///         return target
///     }
/// }
/// ```
///
/// ## Deinitializers
///
/// If you find the need to perform custom behavior when a target object is
/// deallocated, you can declare a `deinitializer` function (**not** `deinit`).
/// For more information, see `ClassHookProtocol.deinitializer()`.
///
/// # Adding to the Class
///
/// ## Properties
///
/// Use the `@Property` property wrapper. For more information, refer to its
/// documentation.
///
/// ## Protocols
///
/// You can specify a list of protocols for which conformance will be added
/// to the class, by declaring the `ClassHookProtocol.protocols` property.
///
/// ## New Methods
///
/// To add a new method to the target class, simply declare it on the hook and mark
/// it as `final`. This may be useful, for example, to make the target class conform
/// to a protocol requirement.
///
/// # Creating Subclasses
///
/// In some situations, you may need to declare a subclass for a base class which is
/// not known at compile-time. In this case, create a `ClassHook` with the `Target`
/// or `targetName` as the base class, and declare the `subclassMode` property with
/// a value of `SubclassMode.createSubclass` (to automatically pick a subclass name)
/// or use `SubclassMode.createSubclassNamed(_:)` if you need a specific name.
///
/// The static `target` property will refer to the subclass type. It is possible
/// to add methods, properties, protocols, and so on to the subclass as described
/// above.
///
/// # Example
///
/// To change the text of all `UILabel`s to "hello", one could write something like this:
///
/// ```
/// class MyHook: ClassHook<UILabel> {
///     func setText(_ text: String) {
///         orig.setText("hello")
///     }
/// }
/// ```
///
public typealias ClassHook<Target: AnyObject> = ClassHookProtocol & _ClassHookClass<Target>
// swiftlint:enable line_length
// we don't declare ClassHookProtocol conformance on ClassHookClass directly since that would
// result in ClassHookClass inheriting the default implementations of ClassHookProtocol and
// AnyHook requirements, making it more difficult to override them

extension ClassHookProtocol {

    // These are `@_transparent` to allow control flow information from
    // `disableRecursionCheck()` to carry through to callers.

    /// A proxy to access the original instance methods of the hooked class.
    @_transparent
    public var orig: Self {
        disableRecursionCheck()
        guard let target = target as? _Glue.OrigType.Target, let unwrapped = _Glue.OrigType(target: target) as? Self
            else { orionError("Could not get orig") }
        return unwrapped
    }

    /// A proxy to access the original class methods of the hooked class.
    @_transparent
    public static var orig: Self.Type {
        disableRecursionCheck()
        guard let unwrapped = _Glue.OrigType.self as? Self.Type
            else { orionError("Could not get orig") }
        return unwrapped
    }

    /// A proxy to access the hooked class' superclass instance methods.
    @_transparent
    public var supr: Self {
        disableRecursionCheck()
        guard let target = target as? _Glue.SuprType.Target, let unwrapped = _Glue.SuprType(target: target) as? Self
            else { orionError("Could not get supr") }
        return unwrapped
    }

    /// A proxy to access the hooked class' superclass class methods.
    @_transparent
    public static var supr: Self.Type {
        disableRecursionCheck()
        guard let unwrapped = _Glue.SuprType.self as? Self.Type
            else { orionError("Could not get supr") }
        return unwrapped
    }

}

extension ClassHookProtocol {
    /// The concrete type of the hooked target (or its subclass depending on
    /// `subclassMode`).
    public static var target: Target.Type {
        // this is in an extension so users can't accidentally override it
        guard let target = _Glue.storage.targetType as? Target.Type else {
            orionError("Got unexpected target type for \(self)")
        }
        return target
    }
}

/// :nodoc:
extension ClassHookProtocol {
    public static var group: Group {
        guard let group = _Glue.storage.group as? Group else {
            orionError("Got unexpected group type for \(self)")
        }
        return group
    }
}

enum ClassHookError: Error {
    case targetNotFound
    case targetHasIncompatibleType(expected: AnyClass, found: AnyClass)
    case subclassCreationFailed
    case protocolAdditionFailed
    case addedMethodNotFound
    case additionFailed
}
