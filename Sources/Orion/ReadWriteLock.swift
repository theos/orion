import Foundation

final class ReadWriteLock {

    private var lock: pthread_rwlock_t

    @discardableResult
    private static func check(
        _ result: Int32,
        _ message: @autoclosure () -> String = "An error occurred",
        file: StaticString = #file,
        line: UInt = #line
    ) -> Bool {
        guard result == 0 else {
            assertionFailure("\(message()): \(String(cString: strerror(result)))", file: file, line: line)
            return false
        }
        return true
    }

    init() {
        var lock = pthread_rwlock_t()
        Self.check(pthread_rwlock_init(&lock, nil))
        self.lock = lock
    }

    deinit {
        Self.check(pthread_rwlock_destroy(&lock), "Could not destroy read-write lock")
    }

    func unlock() {
        Self.check(pthread_rwlock_unlock(&lock), "Could not unlock read-write lock")
    }

    func readLock() {
        Self.check(pthread_rwlock_rdlock(&lock), "Could not acquire read lock")
    }
    func tryReadLock() -> Bool {
        let result = pthread_rwlock_tryrdlock(&lock)
        return result != EBUSY && Self.check(result, "Could not acquire read lock")
    }
    func withReadLock<Result>(_ block: () throws -> Result) rethrows -> Result {
        readLock()
        defer { unlock() }
        return try block()
    }

    func writeLock() {
        Self.check(pthread_rwlock_wrlock(&lock), "Could not acquire write lock")
    }
    func tryWriteLock() -> Bool {
        let result = pthread_rwlock_trywrlock(&lock)
        return result != EBUSY && Self.check(result, "Could not acquire write lock")
    }
    func withWriteLock<Result>(_ block: () throws -> Result) rethrows -> Result {
        writeLock()
        defer { unlock() }
        return try block()
    }

}
