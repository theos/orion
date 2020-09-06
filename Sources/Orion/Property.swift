import Foundation

private class PropertyKeys {

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

    func key(for keyPath: AnyKeyPath) -> UnsafeRawPointer {
        // it's safe to not retain here because the Set retains the key path permanently
        UnsafeRawPointer(Unmanaged.passUnretained(unique(keyPath)).toOpaque())
    }

}

@propertyWrapper public struct Property<T> {
    @available(*, unavailable, message: "@Property is only available on ClassHook types")
    public var wrappedValue: T {
        get { fatalError("@Property is only available on ClassHook types") }
        set { fatalError("@Property is only available on ClassHook types") }
    }

    public enum Weak {
        case weak
    }

    public enum Atomicity {
        case atomic
        case nonatomic
    }

    public enum RetainOrCopy {
        case retain
        case copy
    }

    private let policy: objc_AssociationPolicy
    private let initialValue: T

    public init(wrappedValue: T, _ weak: Weak) {
        self.policy = .OBJC_ASSOCIATION_ASSIGN
        self.initialValue = wrappedValue
    }

    public init(wrappedValue: T, _ atomicity: Atomicity, _ retainOrCopy: RetainOrCopy) {
        switch (atomicity, retainOrCopy) {
        case (.atomic, .retain): policy = .OBJC_ASSOCIATION_RETAIN
        case (.atomic, .copy): policy = .OBJC_ASSOCIATION_COPY
        case (.nonatomic, .retain): policy = .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        case (.nonatomic, .copy): policy = .OBJC_ASSOCIATION_COPY_NONATOMIC
        }
        self.initialValue = wrappedValue
    }

    public init(wrappedValue: T, _ retainOrCopy: RetainOrCopy, _ atomicity: Atomicity) {
        self.init(wrappedValue: wrappedValue, atomicity, retainOrCopy)
    }

    public init(wrappedValue: T, _ retainOrCopy: RetainOrCopy) {
        self.init(wrappedValue: wrappedValue, .atomic, retainOrCopy)
    }

    public init(wrappedValue: T, _ atomicity: Atomicity) {
        self.init(wrappedValue: wrappedValue, atomicity, .retain)
    }

    public init(wrappedValue: T) {
        self.policy = .OBJC_ASSOCIATION_RETAIN
        self.initialValue = wrappedValue
    }

    public static subscript<EnclosingSelf>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, T>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Property<T>>
    ) -> T where EnclosingSelf: _ClassHookProtocol {
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
