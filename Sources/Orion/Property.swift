import Foundation

/// Storage for associated object keys corresponding to `KeyPath`s.
final class PropertyKeys {
    // this class is not private so that we can test it

    // we could use DispatchQueue with a barrier but that's affected by the existence of other
    // queues and QoS stuff, so pthread is slightly faster.
    private let lock = ReadWriteLock()

    // `uniquedKeyPaths` ensures that if two KeyPaths are equal, we return the same address
    // (namely, the first address we used for that key path) even if the newer key path has
    // a different address. Thus, each class-property pair effectively maps to a single
    // address.
    //
    // Although the compiler also attempts to do some uniquing, it's still possible to create
    // new key path allocations using .appending (or cross-module stuff?) so we still need to
    // do uniquing ourselves too. Plus we shouldn't rely on optimizations; there's no guarantee
    // that key paths will be uniqued at all by the compiler.
    private var uniquedKeyPaths: Set<AnyKeyPath> = []

    private init() {}

    static let shared = PropertyKeys()

    private func unique(_ keyPath: AnyKeyPath) -> AnyKeyPath {
        // fast path: use a shared reader lock to check if the value already exists in
        // the set, and if so, return it
        lock.withReadLock {
            uniquedKeyPaths.firstIndex(of: keyPath).map { uniquedKeyPaths[$0] }
        } ?? lock.withWriteLock { // if it doesn't exist, acquire an exclusive writer lock to insert it.
            // there's a chance another thread beat us to acquiring the lock, but that's
            // alright because we return memberAfterInsert, which will be the other thread's
            // keypath if that thread acquired the lock first
            uniquedKeyPaths.insert(keyPath).memberAfterInsert
        }
    }

    /// Provides a unique address corresponding to the provided `keyPath`.
    ///
    /// This method is injective: `key(for: k1) == key(for: k2)` iff `k1 == k2`.
    func key(for keyPath: AnyKeyPath) -> UnsafeRawPointer {
        // it's safe to not retain here because the Set retains the key path permanently
        UnsafeRawPointer(Unmanaged.passUnretained(unique(keyPath)).toOpaque())
    }

}

/// A property wrapper which allows `ClassHook` types to add new properties to their
/// hooked class.
///
/// This type is an ergonomic wrapper around Objective-C associated objects. The
/// type of the associated object is the generic argument `T`.
///
/// If you are declaring a property on a `ClassHook`, you likely want to use this.
/// Note that this property _only_ works on types which conform to `ClassHook`.
///
/// - Important: All properties with this attribute **must** have a default value.
///
/// # Attributes
///
/// This property wrapper gives you the ability to specify attributes on the
/// property, which are similar to those used by Objective-C's `@property`. For
/// a description of each attribute, see `Property.Assign`, `Property.Atomicity`,
/// and `Property.RetainOrCopy`.
///
/// The default attributes are `atomic` and `retain`. Specifying `assign`
/// will replace both defaults, and specifying an atomicity and/or retain
/// policy will only override the respective default.
///
/// # Example
///
/// ```
/// @objcMembers class Person: NSObject {
///     dynamic func sayHello() -> String {
///         "hello"
///     }
/// }
///
/// class PersonHook: ClassHook<Person> {
///     @Property(.nonatomic) var x = 0
///
///     func sayHello() -> String {
///         x += 1
///         return "Hi! I've been called \(x) time(s)"
///     }
/// }
///
/// // later...
///
/// let alice = Person()
/// alice.sayHello() // Hi! I've been called 1 time(s)
/// alice.sayHello() // Hi! I've been called 2 time(s)
///
/// let bob = Person()
/// bob.sayHello() // Hi! I've been called 1 time(s)
/// bob.sayHello() // Hi! I've been called 2 time(s)
/// ```
@propertyWrapper public struct Property<T> {
    /// `@propertyWrapper` implementation. Do not use this property.
    ///
    /// :nodoc:
    @available(*, unavailable, message: "@Property is only available on ClassHook types")
    public var wrappedValue: T {
        get { orionError("@Property is only available on ClassHook types") }
        // swiftlint:disable:next unused_setter_value
        set { orionError("@Property is only available on ClassHook types") }
    }

    /// An enumeration indicating that the property should use the `assign`
    /// attribute.
    public enum Assign {

        /// Indicates that the target object is not responsible for keeping the
        /// property alive.
        ///
        /// This attribute cannot be combined with any other attributes.
        ///
        /// - Warning: If the underlying value is deallocated, it becomes a
        /// dangling pointer and accessing it is undefined behavior.
        case assign

    }

    /// An enumeration containing attributes which allow specifying the
    /// atomicity of the association.
    public enum Atomicity {

        /// The association is made atomically.
        ///
        /// Mutually exclusive with `nonatomic`.
        case atomic

        /// The association is made non-atomically.
        ///
        /// Mutually exclusive with `atomic`.
        case nonatomic

    }

    /// An enumeration containing attributes which determine whether
    /// the property is retained or copied.
    public enum RetainOrCopy {

        /// The property is strongly retained by the target.
        ///
        /// Mutually exclusive with `copy`.
        case retain

        /// The property is copied.
        ///
        /// Mutually exclusive with `retain`.
        case copy

    }

    private let policy: objc_AssociationPolicy
    private let initialValue: T

    /// Initialize the property wrapper.
    ///
    /// :nodoc:
    public init(wrappedValue: T, _ assign: Assign) {
        // despite the documentation, this behaves closer to `assign` or
        // `unsafe_unretained` than it does to `weak`
        self.policy = .OBJC_ASSOCIATION_ASSIGN
        self.initialValue = wrappedValue
    }

    /// Initialize the property wrapper.
    ///
    /// :nodoc:
    public init(wrappedValue: T, _ atomicity: Atomicity, _ retainOrCopy: RetainOrCopy) {
        // https://nshipster.com/associated-objects/
        switch (atomicity, retainOrCopy) {
        case (.atomic, .retain): policy = .OBJC_ASSOCIATION_RETAIN
        case (.atomic, .copy): policy = .OBJC_ASSOCIATION_COPY
        case (.nonatomic, .retain): policy = .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        case (.nonatomic, .copy): policy = .OBJC_ASSOCIATION_COPY_NONATOMIC
        }
        self.initialValue = wrappedValue
    }

    /// Initialize the property wrapper.
    ///
    /// :nodoc:
    public init(wrappedValue: T, _ retainOrCopy: RetainOrCopy, _ atomicity: Atomicity) {
        self.init(wrappedValue: wrappedValue, atomicity, retainOrCopy)
    }

    /// Initialize the property wrapper.
    ///
    /// :nodoc:
    public init(wrappedValue: T, _ retainOrCopy: RetainOrCopy) {
        self.init(wrappedValue: wrappedValue, .atomic, retainOrCopy)
    }

    /// Initialize the property wrapper.
    ///
    /// :nodoc:
    public init(wrappedValue: T, _ atomicity: Atomicity) {
        self.init(wrappedValue: wrappedValue, atomicity, .retain)
    }

    /// Initialize the property wrapper.
    ///
    /// :nodoc:
    public init(wrappedValue: T) {
        self.policy = .OBJC_ASSOCIATION_RETAIN
        self.initialValue = wrappedValue
    }

    /// `@propertyWrapper` implementation.
    ///
    /// :nodoc:
    public static subscript<EnclosingSelf>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, T>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Property<T>>
    ) -> T where EnclosingSelf: ClassHookProtocol {
        get {
            objc_getAssociatedObject(
                object.target,
                PropertyKeys.shared.key(for: wrappedKeyPath)
            ) as? T
                ?? object[keyPath: storageKeyPath].initialValue
        }
        set {
            objc_setAssociatedObject(
                object.target,
                PropertyKeys.shared.key(for: wrappedKeyPath),
                newValue,
                object[keyPath: storageKeyPath].policy
            )
        }
    }
}
