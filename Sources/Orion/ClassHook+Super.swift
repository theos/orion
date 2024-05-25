import Foundation
#if SWIFT_PACKAGE
@_implementationOnly import OrionC
#else
@_implementationOnly import Orion.Private
#endif

// based on https://github.com/SSheldon/rust-objc/tree/95bce4e0d7fa99efebbd135a47cb7dec54710261/src/message/apple
enum MessageSendSuperType {
    case regular
    #if arch(i386) || arch(x86_64) || arch(arm)
    case stret
    #endif
    // no need for fp[2]ret because those are only necessary
    // if we can message nil, which we can't be doing since
    // super can only be called on a non-nil receiver

    init<ReturnType>(for type: ReturnType.Type) {
        #if arch(i386)
        let size = MemoryLayout<ReturnType>.size
        self = size == 0 || size == 1 || size == 2 || size == 4 || size == 8 ? .regular : .stret
        #elseif arch(x86_64)
        self = MemoryLayout<ReturnType>.size <= 16 ? .regular : .stret
        #elseif arch(arm)
        self = MemoryLayout<ReturnType>.size <= 4
            || ReturnType.self is Double.Type
            || ReturnType.self is UInt64.Type
            || ReturnType.self is Int64.Type
            ? .regular : .stret
        #elseif arch(arm64)
        self = .regular
        #else
        #error("Unsupported architecture. Only x86, x86_64, arm, and arm64 are currently supported.")
        #endif
    }

    func send(receiver: Any, cls: AnyClass, block: (UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Void) {
        let sendFn: (Any, AnyClass, (UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Void) -> Void
        switch self {
        case .regular:
            sendFn = _orion_with_objc_super
        #if arch(i386) || arch(x86_64) || arch(arm)
        case .stret:
            sendFn = _orion_with_objc_super_stret
        #endif
        }
        sendFn(receiver, cls, block)
    }
}

/// :nodoc:
extension _GlueClassHookTrampoline {
    private static func callSuper<ReturnType, MessageType>(
        _ type: MessageType.Type,
        receiver: Any,
        cls: AnyClass,
        send: (MessageType, UnsafeRawPointer) -> ReturnType
    ) -> ReturnType {
        var result: ReturnType!
        MessageSendSuperType(for: ReturnType.self).send(receiver: receiver, cls: cls) {
            result = send(unsafeBitCast($1, to: MessageType.self), UnsafeRawPointer($0))
        }
        return result
    }

    public static func callSuper<ReturnType, SuperType>(
        _ type: SuperType.Type,
        send: (SuperType, UnsafeRawPointer) -> ReturnType
    ) -> ReturnType {
        callSuper(type, receiver: target, cls: object_getClass(target)!, send: send)
    }

    public func callSuper<ReturnType, SuperType>(
        _ type: SuperType.Type,
        send: (SuperType, UnsafeRawPointer) -> ReturnType
    ) -> ReturnType {
        Self.callSuper(type, receiver: target, cls: Self.target, send: send)
    }
}
