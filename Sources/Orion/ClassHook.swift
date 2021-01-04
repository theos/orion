import Foundation

/// An enumeration describing a `ClassHook`'s subclassing behavior.
public enum SubclassMode {

    /// Do not create a subclass for this hook.
    case none

    /// Create a subclass with a name derived from the hook name.
    case createSubclass

    /// Create a subclass with the provided name.
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

/// The protocol to which class hooks conform. Do not conform to this
/// directly; use `ClassHook`.
public protocol ClassHookProtocol: class, AnyHook {

    /// The type of the target. Specify this via the generic argument on
    /// `ClassHook`.
    ///
    /// This type must be either the target's own class or a class in
    /// its inheritance chain.
    associatedtype Target: AnyObject

    /// The storage for the underlying target. Do not implement
    /// or use this yourself.
    ///
    /// :nodoc:
    static var _target: Target.Type { get }

    /// The name of the target class, or the empty string to use `Target.self`.
    ///
    /// This class must be `Target` or a subclass of `Target`. Defaults to
    /// an empty string.
    static var targetName: String { get }

    /// If this is not `.none`, it indicates that this hook creates a subclass.
    ///
    /// The created subclass can be accessed via the static `target` property. The
    /// default value is `.none`.
    ///
    /// This property is implemented by creating a new class pair on top of the
    /// original target, when the property is not `.none`.
    static var subclassMode: SubclassMode { get }

    /// An array of protocols which should be added to the target class.
    ///
    /// The default value is an empty array.
    static var protocols: [Protocol] { get }

    /// The current instance of the hooked class, upon which a hooked method
    /// has been called.
    var target: Target { get }

    /// Initializes the type with the provided target instance. Do not invoke
    /// or override this.
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

    public static var _target: Target.Type {
        fatalError("Could not get target. Has the Orion glue file been compiled?")
    }

    public static var subclassMode: SubclassMode { .none }

    public static var protocols: [Protocol] { [] }

    public func deinitializer() -> DeinitPolicy { .callOrig }

}

/// The class which all class hooks inherit from. Do not subclass
/// this directly; use `ClassHook`.
///
/// :nodoc:
@objcMembers open class ClassHookClass<Target: AnyObject> {

    /// The current instance of the hooked class, upon which a hooked method
    /// has been called.
    public let target: Target

    /// Initializes the type with the provided target instance. Do not invoke
    /// or override this.
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
/// ```func `init`() -> Target```.
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
public typealias ClassHook<Target: AnyObject> = ClassHookClass<Target> & ClassHookProtocol
// swiftlint:enable line_length
// we don't declare _ClassHookProtocol conformance on _ClassHookClass directly since that would
// result in _ClassHookClass inheriting the default implementations of _ClassHookProtocol and
// _AnyHook requirements, making it more difficult to override them

extension ClassHookProtocol {

    /// The concrete type of the hooked target (or its subclass depending on
    /// `subclassMode`).
    public static var target: Target.Type {
        // this is in an extension so users can't accidentally override it
        _target
    }

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

    /// A proxy to access the original instance methods of the hooked class.
    @_transparent
    public var orig: Self {
        guard let unwrapped = (self as? _AnyGlueClassHook)?._orig as? Self
            else { _indirectFatalError("Could not get orig") }
        return unwrapped
    }

    /// A proxy to access the original class methods of the hooked class.
    @_transparent
    public static var orig: Self.Type {
        guard let unwrapped = (self as? _AnyGlueClassHook.Type)?._orig as? Self.Type
            else { _indirectFatalError("Could not get orig") }
        return unwrapped
    }

    /// A proxy to access the hooked class' superclass instance methods.
    @_transparent
    public var supr: Self {
        guard let unwrapped = (self as? _AnyGlueClassHook)?._supr as? Self
            else { _indirectFatalError("Could not get supr") }
        return unwrapped
    }

    /// A proxy to access the hooked class' superclass class methods.
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
            else { fatalError("Could not find method \(methodDescription())") }
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
