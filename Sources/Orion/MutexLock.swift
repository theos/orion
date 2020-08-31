import Foundation

final class MutexLock {

    private var _lock: pthread_mutex_t

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
        var lock = pthread_mutex_t()
        Self.check(pthread_mutex_init(&lock, nil))
        _lock = lock
    }

    deinit {
        Self.check(pthread_mutex_destroy(&_lock), "Could not destroy mutex lock")
    }

    func unlock() {
        Self.check(pthread_mutex_unlock(&_lock), "Could not unlock mutex lock")
    }

    func lock() {
        Self.check(pthread_mutex_lock(&_lock), "Could not acquire mutex lock")
    }
    func tryLock() -> Bool {
        let result = pthread_mutex_trylock(&_lock)
        return result != EBUSY && Self.check(result, "Could not acquire mutex lock")
    }
    func withLock<Result>(_ block: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try block()
    }

}
