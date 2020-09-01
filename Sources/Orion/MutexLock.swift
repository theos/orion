import Foundation

final class MutexLock {

    struct Options {
        enum MutexType {
            case normal
            case errorCheck
            case recursive
            case `default`

            var raw: Int32 {
                switch self {
                case .normal: return PTHREAD_MUTEX_NORMAL
                case .errorCheck: return PTHREAD_MUTEX_ERRORCHECK
                case .recursive: return PTHREAD_MUTEX_RECURSIVE
                case .default: return PTHREAD_MUTEX_DEFAULT
                }
            }
        }

        var type: MutexType = .default

        @discardableResult
        fileprivate func withRaw<Result>(_ block: (inout pthread_mutexattr_t) throws -> Result) rethrows -> Result {
            var attr = pthread_mutexattr_t()
            MutexLock.check(pthread_mutexattr_init(&attr))
            // once the mutex is created, changing/destroying the attr doesn't
            // affect it so this is safe
            defer { pthread_mutexattr_destroy(&attr) }

            MutexLock.check(pthread_mutexattr_settype(&attr, type.raw))

            return try block(&attr)
        }
    }

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

    init(options: Options = .init()) {
        var lock = pthread_mutex_t()
        options.withRaw { Self.check(pthread_mutex_init(&lock, &$0)) }
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
