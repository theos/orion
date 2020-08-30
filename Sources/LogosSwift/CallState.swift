import Foundation

public enum CallStateTransition {
    // don't perform any locking
    case nonatomic
    // lock during the call
    case atomic

    public static let `default`: CallStateTransition = .atomic
}

public class CallState<Request> {
    private let lock = MutexLock()
    private var currentRequest: (CallStateTransition, Request)?

    public init() {}

    func makeRequest(_ request: Request, transition: CallStateTransition) {
        if transition == .atomic { lock.lock() }
        currentRequest = (transition, request)
    }

    public func fetchRequest() -> Request? {
        guard let request = currentRequest else { return nil }
        currentRequest = nil
        if request.0 == .atomic { lock.unlock() }
        return request.1
    }
}
