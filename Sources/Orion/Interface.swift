import Foundation

@objc protocol AllocInterface {
    func alloc() -> Unmanaged<NSObject>
}

extension NSObject {

    // We can possibly get slightly better performance using @_effects but I'm not confident enough to try that. See:
    // https://github.com/apple/swift/blob/4cf4515f1c50a37edc819c15dfde791e420a4863/stdlib/public/core/StringBridge.swift#L68-L75
    public func `as`<I>(interface: I.Type) -> I {
        unsafeBitCast(self, to: interface)
    }

    // usage: declare interface methods as non-static but use them on the static type. If NSProtocolFromString doesn't
    // work, pass the protocol again a second time, as the `protocol` argument
    public static func `as`<I>(interface: I.Type, protocol: Protocol? = nil) -> I {
        // we use init(reflecting:) to get the fully qualified protocol name
        guard let proto = `protocol` ?? NSProtocolFromString(String(reflecting: interface))
            else { fatalError("\(interface) is not an @objc protocol") }
        class_addProtocol(self, proto)
        guard let typed = self as? I
            else { fatalError("Failed to make \(self) conform to \(interface)") }
        return typed
    }

    public static func alloc<I>(interface: I.Type) -> I {
        `as`(interface: AllocInterface.self).alloc().takeRetainedValue().as(interface: interface)
    }

}

public func Class(_ name: String) -> AnyClass {
    guard let cls = NSClassFromString(name)
        else { fatalError("Could not find class named \(name)") }
    return cls
}

public func Class<I>(_ name: String, interface: I.Type) -> I {
    guard let ns = Class(name) as? NSObject.Type
        else { fatalError("Class \(name) does not conform to NSObject") }
    return ns.as(interface: interface)
}

public func Class<T>(_ name: String, type: T.Type) -> T.Type {
    guard let typed = Class(name) as? T.Type
        else { fatalError("Could not convert class \(name) to type \(type)") }
    return typed
}
