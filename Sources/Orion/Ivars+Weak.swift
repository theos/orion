import Foundation

/// A protocol-based definition of `Optional`. Do not use this in
/// your own code.
///
/// :nodoc:
public protocol _OptionalProtocol {
    associatedtype Wrapped

    // we can't declare .some and .none as protocol witnesses
    // since a) that requires Swift 5.3+ and b) there's
    // a bug with that in Swift 5.3:
    // https://bugs.swift.org/browse/SR-14071
    init(_orionOptional: Wrapped?)
}

/// :nodoc:
extension Optional: _OptionalProtocol {
    public init(_orionOptional: Wrapped?) {
        self = _orionOptional
    }
}

extension Ivars where IvarType: _OptionalProtocol, IvarType.Wrapped: AnyObject {
    /// An enumeration indicating that the instance variable in question
    /// uses `weak` semantics.
    public enum WeakStorage {
        // we don't directly use `Storage` since we may want future
        // storage types to only work under other specific conditions
        // (for example a `.unowned` which only works when IvarType
        // conforms to AnyObject directly)
        /// Indicates that the instance variable uses `weak` semantics.
        case weak
    }

    /// Construct a new instance of `Ivars` for accessing weak Objective-C
    /// instance variables on `object`.
    ///
    /// This initializer requires that `IvarType` be an optional object type.
    ///
    /// For example, to access a weak string ivar `_foo` on `obj`, you could use
    /// `Ivars<NSString?>(obj, .weak)._foo`.
    ///
    /// - Parameter object: The object on which ivars are to be accessed.
    ///
    /// - Parameter storage: Set this to `WeakStorage.weak`. Indicates that the
    /// instance variable is weak.
    public init(_ object: AnyObject, _ storage: WeakStorage) {
        self.object = object
        self.storage = .weak
    }
}

extension Ivars {
    // allows us to deterministically call the more general overloads

    private func indirectSafeSubscriptGetter(ivarName: String) -> IvarType? {
        self[safelyAccessing: ivarName]
    }

    private func indirectSafeSubscriptSetter(ivarName: String, newValue: IvarType?) {
        self[safelyAccessing: ivarName] = newValue
    }

    private func indirectDynamicSubscriptGetter(ivarName: String) -> IvarType {
        self[dynamicMember: ivarName]
    }

    private func indirectDynamicSubscriptSetter(ivarName: String, newValue: IvarType) {
        self[dynamicMember: ivarName] = newValue
    }
}

/// :nodoc:
extension Ivars where IvarType: _OptionalProtocol, IvarType.Wrapped: AnyObject {
    /// Access an Objective-C instance variable on the object, failing gracefully
    /// if the instance variable does not exist.
    ///
    /// - Parameter ivarName: The name of the instance variable to access.
    ///
    /// - Returns: The value of the instance variable, or `nil` if there is
    /// no ivar with the given name.
    ///
    /// - Note: If the setter is passed a value of `nil`, it will do nothing.
    public subscript(safelyAccessing ivarName: String) -> IvarType? {
        get {
            guard storage == .weak else {
                return indirectSafeSubscriptGetter(ivarName: ivarName)
            }
            return withIvar(ivarName) {
                guard let pointer = $0 else { return nil }
                guard let loaded = objc_loadWeak(.init(pointer))
                    else { return IvarType(_orionOptional: nil) }
                guard let converted = loaded as? IvarType.Wrapped
                    else { return nil }
                return IvarType(_orionOptional: converted)
            }
        }
        nonmutating set {
            guard storage == .weak else {
                return indirectSafeSubscriptSetter(ivarName: ivarName, newValue: newValue)
            }
            guard let newValue = newValue else { return }
            withIvar(ivarName) {
                guard let pointer = $0 else { return }
                objc_storeWeak(.init(pointer), newValue)
            }
        }
    }

    /// Access an Objective-C instance variable on the object.
    ///
    /// - Parameter ivarName: The name of the instance variable to access.
    ///
    /// - Precondition: The ivar `ivarName` **must** be present on the object.
    /// If an ivar with the given name is not present, using this subscript
    /// will result in a crash.
    ///
    /// To fail gracefully, use `Ivars.subscript(safelyAccessing:)` or `Ivars.withIvar(_:_:)`.
    public subscript(dynamicMember ivarName: String) -> IvarType {
        get {
            guard storage == .weak else {
                return indirectDynamicSubscriptGetter(ivarName: ivarName)
            }
            return withIvar(ivarName) {
                guard let pointer = $0
                    else { orionError("Ivar '\(ivarName)' not found on object \(object)") }
                guard let loaded = objc_loadWeak(.init(pointer))
                    else { return IvarType(_orionOptional: nil) }
                guard let converted = loaded as? IvarType.Wrapped else {
                    orionError("""
                    Ivar '\(ivarName)' does not have the expected type \(IvarType.Wrapped.self)
                    """)
                }
                return IvarType(_orionOptional: converted)
            }
        }
        nonmutating set {
            guard storage == .weak else {
                return indirectDynamicSubscriptSetter(ivarName: ivarName, newValue: newValue)
            }
            withIvar(ivarName) {
                guard let pointer = $0
                    else { orionError("Ivar '\(ivarName)' not found on object \(object)") }
                objc_storeWeak(.init(pointer), newValue)
            }
        }
    }

}
