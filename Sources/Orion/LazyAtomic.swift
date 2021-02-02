import Foundation

@propertyWrapper class LazyAtomic<T> {
    private let lock = ReadWriteLock()
    private let compute: () -> T

    private var stored: T?

    var wrappedValue: T {
        get {
            lock.withReadLock {
                stored
            } ?? lock.withWriteLock {
                // check if another thread beat us first
                if let cached = stored {
                    return cached
                }
                let computed = compute()
                stored = computed
                return computed
            }
        }
        set {
            lock.withWriteLock {
                stored = newValue
            }
        }
    }

    init(wrappedValue: @autoclosure @escaping () -> T) {
        self.compute = wrappedValue
    }
}
