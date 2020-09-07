import Foundation

@objc protocol AllocInterface {
    func alloc() -> Unmanaged<AnyObject>
}

// API inspired by https://github.com/mhdhejazi/Dynamic
@dynamicMemberLookup public struct Dynamic {

    private enum Guts {
        case cls(AnyClass)
        case proto(Protocol)
        case name(String)

        var cls: AnyClass {
            switch self {
            case .cls(let cls): return cls
            case .proto: fatalError("Cannot convert protocol to class")
            case .name(let name):
                guard let cls = NSClassFromString(name)
                    else { fatalError("Could not find class named \(name)") }
                return cls
            }
        }

        var proto: Protocol {
            switch self {
            case .cls: fatalError("Cannot convert class to protocol")
            case .proto(let proto): return proto
            case .name(let name):
                guard let cls = NSProtocolFromString(name)
                    else { fatalError("Could not find protocol named \(name)") }
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
    public var `class`: AnyClass { guts.cls }
    public var `protocol`: Protocol { guts.proto }

    private init(_ guts: Guts) {
        self.guts = guts
    }

    public init(_ cls: AnyClass) {
        self.init(.cls(cls))
    }

    public init(_ name: String) {
        self.init(.name(name))
    }

    public static subscript(dynamicMember className: String) -> Self {
        self.init(className)
    }

    // Dynamic("Foo").appending(component: "Bar") == Dynamic("Foo.Bar")
    public func appending(component: String) -> Self {
        .init(guts.appending(component: component))
    }

    // this effectively allows users to do something like `Dynamic.Foo.Bar`, which translates to
    // Dynamic[dynamicMember: "Foo"][dynamicMember: "Bar"]
    public subscript(dynamicMember component: String) -> Self {
        appending(component: component)
    }

    // We can possibly get slightly better performance using @_effects but I'm not confident enough to try that. See:
    // https://github.com/apple/swift/blob/4cf4515f1c50a37edc819c15dfde791e420a4863/stdlib/public/core/StringBridge.swift#L68-L75
    public static func convert<I>(_ object: AnyObject, to interface: I.Type) -> I {
        unsafeBitCast(object, to: interface)
    }

    public func `as`<T: AnyObject>(type: T.Type) -> T.Type {
        guard let typed = `class` as? T.Type
            else { fatalError("Could not convert class \(`class`) to type \(type)") }
        return typed
    }

    // usage: declare interface methods as non-static but use them on the static type. If NSProtocolFromString doesn't
    // work, pass the protocol again a second time, as the `protocol` argument
    public func `as`<I>(interface: I.Type, protocol: Protocol? = nil) -> I {
        // we use init(reflecting:) to get the fully qualified protocol name
        guard let proto = `protocol` ?? NSProtocolFromString(String(reflecting: interface))
            else { fatalError("\(interface) is not an @objc protocol") }
        class_addProtocol(`class`, proto)
        guard let typed = `class` as? I
            else { fatalError("Failed to make \(`class`) conform to \(interface)") }
        return typed
    }

    public func alloc<I>(interface: I.Type) -> I {
        Self.convert(self.as(interface: AllocInterface.self).alloc().takeRetainedValue(), to: interface)
    }

}

extension NSObject {

    public func `as`<I>(interface: I.Type) -> I {
        Dynamic.convert(self, to: interface)
    }

    public static func `as`<I>(interface: I.Type, protocol: Protocol? = nil) -> I {
        Dynamic(self).as(interface: interface, protocol: `protocol`)
    }

    public static func alloc<I>(interface: I.Type) -> I {
        Dynamic(self).alloc(interface: interface)
    }

}
