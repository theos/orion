import Foundation

/// A wrapper around an object for accessing Objective-C instance variables of
/// type `IvarType` on it.
///
/// This type supports dynamic member lookup, which means that ivars
/// can be accessed as if they were members of the type. Note that if
/// an ivar with the given name does not exist, the dynamic member access
/// will result in a crash.
///
/// - To access a pointer to the ivar instead, use `Ivars.withIvar(_:_:)`.
///
/// - To fail gracefully if the ivar does not exist, use `Ivars.subscript(safelyAccessing:)`.
///
/// - To access an ivar with a name that clashes with an actual member on this type,
/// it is possible to use `Ivars.subscript(dynamicMember:)` directly.
///
/// - To access a weak ivar, pass `.weak` as the second argument to the `Ivars` initializer.
/// The `IvarType` must correspond to an optional of a class (e.g. `Ivars<NSString?>`).
///
/// # Example
///
/// ```
/// let object = MyObject(foo: 5)
/// Ivars<Int>(object)._foo // 5
/// Ivars(object)._foo = 7
/// print(object.foo) // 7
/// ```
@dynamicMemberLookup public struct Ivars<IvarType> {
    enum Storage {
        case strong
        case weak
    }

    let object: AnyObject
    let storage: Storage

    /// Construct a new instance of `Ivars` for accessing Objective-C
    /// instance variables on `object`.
    ///
    /// - Parameter object: The object on which ivars are to be accessed.
    public init(_ object: AnyObject) {
        self.object = object
        self.storage = .strong
    }

    /// Access an Objective-C instance variable on the object.
    ///
    /// - Parameter name: The name of the instance variable to access.
    ///
    /// - Parameter body: A block which receives a pointer to the
    /// ivar, within which it may be read or written to.
    ///
    /// - Parameter pointer: The pointer to the ivar, or `nil` if
    /// `object` does not have an ivar with the provided `name`.
    ///
    /// - Returns: The value returned from `body`.
    ///
    /// It is safe to assume that `body` will be called on all execution paths.
    ///
    /// - Warning: The `pointer` argument should not be stored and used outside
    /// of the lifetime of the call to the closure.
    public func withIvar<Result>(
        _ name: String,
        _ body: (_ pointer: UnsafeMutablePointer<IvarType>?) throws -> Result
    ) rethrows -> Result {
        // Since `MSHookIvar` is a cpp template-based function, we can't directly
        // use it from Swift code. But it's quite trivial to re-implement.
        guard let cls = object_getClass(object),
            let ivar = class_getInstanceVariable(cls, name)
            else { return try body(nil) }
        let offset = ivar_getOffset(ivar)
        // Note that we can't just return the pointer directly because ARC doesn't
        // know that the object's lifetime is tied to it, so it might end up releasing
        // the object prematurely if the object's last direct use was before the last
        // usage of the ivar pointer. This is basically what NS_RETURNS_INNER_POINTER
        // solves, but we can't use that annotation in Swift so this is the second best
        // option. If we had returned the pointer directly, the following could happen:
        //
        // let object = MyClass()
        // object.foo = 5
        // let ptr = Ivars<Int>(object).withIvar("_foo") // assume we return a pointer
        // /* ARC releases `object` since it doesn't see any further usage */
        // print(ptr!.pointee) // use-after-free, might do horrible things!
        return try withExtendedLifetime(object) {
            try body(
                // effectively (IvarType *)((char *)(__bridge void *)object + offset)
                (Unmanaged.passUnretained($0).toOpaque() + offset)
                    .assumingMemoryBound(to: IvarType.self)
            )
        }
    }

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
        get { withIvar(ivarName) { $0?.pointee } }
        nonmutating set {
            guard let newValue = newValue else { return }
            withIvar(ivarName) { $0?.pointee = newValue }
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
            withIvar(ivarName) {
                guard let pointer = $0
                    else { orionError("Ivar '\(ivarName)' not found on object \(object)") }
                return pointer.pointee
            }
        }
        nonmutating set {
            withIvar(ivarName) {
                guard let pointer = $0
                    else { orionError("Ivar '\(ivarName)' not found on object \(object)") }
                pointer.pointee = newValue
            }
        }
    }
}
