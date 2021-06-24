import Foundation

@objc private protocol AllocInterface {
    func alloc() -> Unmanaged<AnyObject>
}

/// A wrapper enabling ergonomic dynamic Objective-C lookup.
///
/// This type can be used as syntactic sugar to access ObjC
/// classes and protocols by name, and also to call undeclared
/// methods on them in a relatively type-safe manner.
///
/// This type is inspired by [mhdhejazi/Dynamic](https://github.com/mhdhejazi/Dynamic).
///
/// # Obtaining an Instance
///
/// Use `Dynamic.TypeName` to get an instance of `Dynamic`. Accessing
/// classes/protocols with dots in their name can be done in the same
/// way: e.g. `Dynamic.Foo.Bar`.
///
/// You can also get an instance of `Dynamic` by passing a string, e.g.
/// `Dynamic("Foo.Bar")`, or even by passing an existing class:
/// `Dynamic(NSString.self)`.
///
/// # Getting the Underlying Type
///
/// If the type name corresponds to an Objective-C class, it is possible
/// to retrieve an `AnyClass` from the type using the `class` property. For
/// example, `Dynamic.TypeName.class` will return the class named "TypeName".
/// To cast to a more specific superclass type, use `as(type:)`, for example
/// `Dynamic.PrivateViewType.as(type: UIView.self)`.
///
/// If the type name corresponds to an Objective-C protocol, the `protocol`
/// property returns the type as a `Protocol`.
///
/// # Calling Undeclared Instance Methods
///
/// The first step to calling an undeclared method on the type (one that is
/// not known to the Swift compiler) is to declare an "interface" with the
/// method. An interface is simply an Objective-C protocol.
///
/// Say you wanted to call `-[MyClass someInstanceMethod]`, where `someInstanceMethod`
/// is not exposed to Swift. First, declare the interface:
///
/// ```
/// @objc protocol MyInterfaceA {
///     func someInstanceMethod()
/// }
/// ```
///
/// Then, use `Dynamic.convert(_:to:)` to "cast" the object to that interface:
///
/// ```
/// let obj = MyClass()
/// let converted = Dynamic.convert(obj, to: MyInterfaceA.self)
/// ```
///
/// Swift sees `converted` as a type conforming to `MyInterface`, and so it
/// is now possible to directly call the method on it:
///
/// ```
/// converted.someInstanceMethod()
/// ```
///
/// If `MyClass` conforms to `NSObject`, a way to do this with even more
/// syntactic sugar is to use `NSObject.as(interface:)`:
///
/// ```
/// MyClass().as(interface: MyInterfaceA.self).someInstanceMethod()
/// ```
///
/// # Calling Undeclared Class Methods
///
/// Calling class methods is similar to calling instance methods. Say you
/// wanted to call `+[MyClass someClassMethod]` where neither the class
/// nor the method is publicly exposed to Swift. First, declare an interface:
///
/// ```
/// @objc protocol MyInterfaceB {
///     func someClassMethod()
/// }
/// ```
///
/// Note that the method is declared as an _instance_ method in the
/// protocol, even though it is actually a class method.
///
/// Next, obtain an instance of `Dynamic` corresponding to the type,
/// and use `Dynamic.as(interface:)` to cast it to the interface.
///
/// ```
/// let converted = Dynamic.MyClass.as(interface: MyInterfaceB.self)
/// ```
///
/// Following this, it is possible to call methods on the type which have
/// been declared on the interface:
///
/// ```
/// converted.someClassMethod()
/// ```
///
/// As with instance methods, class methods too have syntactic sugar
/// available via an extension on `NSObject`. If `MyClass` was accessible
/// in Swift and conformed to `NSObject`, the private method could be
/// called as follows:
///
/// ```
/// MyClass.as(interface: MyInterfaceB.self).someClassMethod()
/// ```
///
/// # Calling Initializers
///
/// In order to call a private initializer using `Dynamic`, declare
/// an interface with the initializer method (escaping \`init\` with
/// backticks if required). Then call `alloc(interface:)` on the class
/// or an instance of `Dynamic` corresponding to it, passing in the
/// interface. Finally, call the initializer method on the returned object.
///
/// For example, initializing `MyClass` using `-[MyClass initWithString:]`
/// would look like this:
///
/// ```
/// @objc protocol MyInterfaceC {
///     func initWithString(_ string: String)
/// }
///
/// let obj = Dynamic.MyClass
///     .alloc(interface: MyInterfaceC.self)
///     .initWithString("hello")
/// ```
///
/// Since `MyClass` conforms to `NSObject`, it is again possible to utilize
/// additional syntactic sugar, in this case replacing `Dynamic.MyClass` with
/// simply `MyClass`.
@dynamicMemberLookup public struct Dynamic {

    private enum Guts {
        case cls(AnyClass)
        case proto(Protocol)
        case name(String)

        var cls: AnyClass {
            switch self {
            case .cls(let cls): return cls
            case .proto: orionError("Cannot convert protocol to class")
            case .name(let name):
                guard let cls = NSClassFromString(name)
                    else { orionError("Could not find class named \(name)") }
                return cls
            }
        }

        var proto: Protocol {
            switch self {
            case .cls: orionError("Cannot convert class to protocol")
            case .proto(let proto): return proto
            case .name(let name):
                guard let cls = NSProtocolFromString(name)
                    else { orionError("Could not find protocol named \(name)") }
                return cls
            }
        }

        var name: String {
            switch self {
            case .cls(let cls): return NSStringFromClass(cls)
            case .proto(let proto): return NSStringFromProtocol(proto)
            case .name(let name): return name
            }
        }

        func appending(component: String) -> Guts {
            .name("\(name).\(component)")
        }
    }

    private let guts: Guts

    /// The class with the given name.
    public var `class`: AnyClass { guts.cls }

    /// The protocol with the given name.
    public var `protocol`: Protocol { guts.proto }

    private init(_ guts: Guts) {
        self.guts = guts
    }

    /// Initialize an instance of `Dynamic` with the given class.
    ///
    /// - Parameter cls: The class with which the instance should be
    /// initialized.
    public init(_ cls: AnyClass) {
        self.init(.cls(cls))
    }

    /// Initialize an instance of `Dynamic` with the given type name.
    ///
    /// - Parameter name: The name of the type with which the instance
    /// should be initialized.
    public init(_ name: String) {
        self.init(.name(name))
    }

    /// Initialize an instance of `Dynamic` with the given type name.
    ///
    /// - Parameter typeName: The name of the type with which the instance
    /// should be initialized.
    public static subscript(dynamicMember typeName: String) -> Self {
        self.init(typeName)
    }

    /// Appends the provided component onto the name of the type, delimited
    /// by a period.
    ///
    /// `Dynamic("Foo").appending(component: "Bar") == Dynamic("Foo.Bar")`
    ///
    /// - Parameter component: The component to append.
    ///
    /// - Returns: A modified copy of the callee with `component` appended
    /// to the name after a period.
    public func appending(component: String) -> Self {
        .init(guts.appending(component: component))
    }

    /// Appends the provided component onto the name of the type, delimited
    /// by a period.
    ///
    /// `Dynamic.Foo.Bar == Dynamic("Foo.Bar")`
    ///
    /// - Parameter component: The component to append.
    ///
    /// - Returns: A modified copy of the callee with `component` appended
    /// to the name after a period.
    public subscript(dynamicMember component: String) -> Self {
        appending(component: component)
    }

    /// Casts the object to the given interface type.
    ///
    /// For more information, see the documentation for the `Dynamic` struct.
    ///
    /// - Parameter object: The object to cast.
    ///
    /// - Parameter interface: The interface to which the object should be
    /// converted.
    ///
    /// - Returns: The object as if it conformed to the given interface.
    public static func convert<I>(_ object: AnyObject, to interface: I.Type) -> I {
        // We can possibly get slightly better performance using @_effects but I'm not confident enough to try that. See:
        // https://github.com/apple/swift/blob/4cf4515f1c50a37edc819c15dfde791e420a4863/stdlib/public/core/StringBridge.swift#L68-L75
        unsafeBitCast(object, to: interface)
    }

    /// Returns the class referred to by the callee, cast to the
    /// provided type.
    ///
    /// - Parameter type: The type to which the class should be cast.
    ///
    /// - Returns: The cast class.
    public func `as`<T: AnyObject>(type: T.Type) -> T.Type {
        guard let typed = `class` as? T.Type
            else { orionError("Could not convert class \(`class`) to type \(type)") }
        return typed
    }

    /// Returns the class referred to by the callee as if it conformed
    /// to the given interface.
    ///
    /// Methods on the interface should be declared as **instance** methods.
    ///
    /// For more information, see the documentation for the `Dynamic` struct.
    ///
    /// - Parameter interface: The interface to which the class should
    /// be cast.
    ///
    /// - Parameter protocol: If the interface is a private protocol or is
    /// otherwise invisible to Objective-C via `NSClassFromString`, you may
    /// need to pass the protocol a second time as this parameter. For example,
    /// `Dynamic.MyClass.as(interface: MyInterface.self, protocol: MyInterface.self)`.
    ///
    /// - Returns: The class, "cast" to the interface.
    public func `as`<I>(interface: I.Type, protocol: Protocol? = nil) -> I {
        // we use init(reflecting:) to get the fully qualified protocol name
        guard let proto = `protocol` ?? NSProtocolFromString(String(reflecting: interface))
            else { orionError("\(interface) is not an @objc protocol") }
        class_addProtocol(`class`, proto)
        guard let typed = `class` as? I
            else { orionError("Failed to make \(`class`) conform to \(interface)") }
        return typed
    }

    /// Allocates an object corresponding to the callee's class and casts it
    /// to the type of the passed interface.
    ///
    /// - Parameter interface: The interface which the allocated type should
    /// be cast to. You usually want this to have an initializer method which
    /// should be chained to this call.
    ///
    /// - Returns: The allocated instance of the class, as the `interface` type.
    public func alloc<I>(interface: I.Type) -> I {
        Self.convert(
            self.as(
                interface: AllocInterface.self,
                protocol: AllocInterface.self
            ).alloc().takeRetainedValue(),
            to: interface
        )
    }

}

extension NSObject {

    /// Casts the receiver to the given interface type.
    ///
    /// For more information, see the documentation for the `Dynamic` struct.
    ///
    /// - Parameter interface: The interface to which the receiver should be
    /// converted.
    ///
    /// - Returns: The receiver as if it conformed to the given interface.
    public func `as`<I>(interface: I.Type) -> I {
        Dynamic.convert(self, to: interface)
    }

    /// Returns the class referred to by the receiver as if it conformed
    /// to the given interface.
    ///
    /// Methods on the interface should be declared as **instance** methods.
    ///
    /// For more information, see the documentation for the `Dynamic` struct.
    ///
    /// - Parameter interface: The interface to which the class should
    /// be cast.
    ///
    /// - Parameter protocol: If the interface is a private protocol or is
    /// otherwise invisible to Objective-C via `NSClassFromString`, you may
    /// need to pass the protocol a second time as this parameter. For example,
    /// `MyClass.as(interface: MyInterface.self, protocol: MyInterface.self)`.
    ///
    /// - Returns: The class, "cast" to the interface.
    public static func `as`<I>(interface: I.Type, protocol: Protocol? = nil) -> I {
        Dynamic(self).as(interface: interface, protocol: `protocol`)
    }

    /// Allocates an object corresponding to the callee's class and casts it
    /// to the type of the passed interface.
    ///
    /// - Parameter interface: The interface which the allocated type should
    /// be cast to. You usually want this to have an initializer method which
    /// should be chained to this call.
    ///
    /// - Returns: The allocated instance of the class, as the `interface` type.
    public static func alloc<I>(interface: I.Type) -> I {
        Dynamic(self).alloc(interface: interface)
    }

}
