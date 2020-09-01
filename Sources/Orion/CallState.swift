import Foundation

public enum CallStateTransition {
    // don't perform any locking
    case nonatomic
    // lock during the call
    case atomic

    public static let `default`: CallStateTransition = .atomic
}

public class CallState<Request> {
    private let lock = MutexLock(options: .init(type: .recursive))
    private var requestStack: [(CallStateTransition, Request)] = []

    public init() {}

    func makeRequest(_ request: Request, transition: CallStateTransition) {
        if transition == .atomic { lock.lock() }
        requestStack.append((transition, request))
    }

    public func fetchRequest() -> Request? {
        guard let request = requestStack.popLast() else { return nil }
        if request.0 == .atomic { lock.unlock() }
        return request.1
    }

    deinit {
        // In case the user doesn't actually call a trampoline inside the
        // method, we should throw an error. If we failed silently, we might
        // end up with unexpected behavior, because if there is an unbalanced
        // atomic request followed by another atomic request on a different
        // thread, it would result in deadlock. There might be other issues
        // too, but this is one I can currently think of.
        //
        // While it might seem more logical to perform this check by ensuring
        // the requestStack level is the equal before and after any block()
        // calls in <ClassHook|FunctionHook>.makeRequest, that's not actually
        // an invariant because our atomicity guarantee only extends to the
        // *start* of the block (when the trampoline calls fetchRequest).
        // Beyond that, during the actual orig/super implementation, or during
        // other functions inside `block` itself, other threads are free to
        // modify the call state stack as they want. Thus it's possible that
        // when `block` exits, another thread has just pushed a call state but
        // hasn't popped it yet, so our sanity check would erroneously fail.
        guard requestStack.isEmpty else {
            fatalError("""
            orig or supr was called inside a hook without actually invoking an \
            original or super function/method
            """)
        }
    }
}
