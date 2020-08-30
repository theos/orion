import Foundation

@objc protocol AllocInterface {
    func alloc() -> Unmanaged<NSObject>
}

extension NSObject {

    // We can possibly get slightly better performance using @_effects but I'm not confident enough to try that. See:
    // https://github.com/apple/swift/blob/4cf4515f1c50a37edc819c15dfde791e420a4863/stdlib/public/core/StringBridge.swift#L68-L75
    public func withInterface<Interface>(_ interface: Interface.Type) -> Interface {
        unsafeBitCast(self, to: interface)
    }

    // usage: declare interface methods as non-static but use them on the static type. If NSProtocolFromString doesn't
    // work, pass the protocol again a second time, as the `protocol` argument
    public static func withInterface<Interface>(_ interface: Interface.Type, protocol: Protocol? = nil) -> Interface {
        // we use init(reflecting:) to get the fully qualified protocol name
        guard let proto = `protocol` ?? NSProtocolFromString(String(reflecting: interface))
            else { fatalError("\(interface) is not an @objc protocol") }
        class_addProtocol(self, proto)
        guard let typed = self as? Interface
            else { fatalError("Failed to make \(self) conform to \(interface)") }
        return typed
    }

    public static func allocWithInterface<Interface>(_ interface: Interface.Type) -> Interface {
        withInterface(AllocInterface.self).alloc().takeRetainedValue().withInterface(interface)
    }

}
