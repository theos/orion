import Foundation

/// A closure which is called when Orion encounters a non-recoverable
/// error.
///
/// - Important: The closure must terminate the program, as
/// implied by the `Never` return value.
///
/// - Parameter message: The error message.
///
/// - Parameter file: The file associated with the error.
///
/// - Parameter line: The line number associated with the error.
public typealias OrionErrorHandler = (
    _ message: @autoclosure () -> String,
    _ file: StaticString,
    _ line: UInt
) -> Never

// swiftlint:disable:next fatal_error
private var orionErrorHandler: OrionErrorHandler = fatalError

private let errorHandlerQueue = DispatchQueue(label: "error-handler-queue")

/// Updates the `OrionErrorHandler` which is called when Orion encounters
/// a non-recoverable error.
///
/// The default error handler is `fatalError`.
///
/// - Important: The new error handler is applied to *all* tweaks, not just
/// the one calling this method.
///
/// - Warning: This function is thread-safe but not reentrant. Do not call
/// `updateOrionErrorHandler(_:)` or `orionError(_:file:line:)` inside the
/// `update` block or the returned error handler.
///
/// - Parameter update: A closure which is passed the previous error handler
/// and returns an updated handler.
///
/// - Parameter previous: The previous error handler. You may want to call this
/// at the end of your error handler closure.
///
/// # Example
///
/// ```
/// updateOrionErrorHandler { old in
///     return { message, file, line in
///         let str = message()
///         // do something with str, file, line
///         old(str, file, line)
///     }
/// }
/// ```
public func updateOrionErrorHandler(
    _ update: (_ previous: @escaping OrionErrorHandler) -> OrionErrorHandler
) {
    errorHandlerQueue.sync {
        orionErrorHandler = update(orionErrorHandler)
    }
}

/// Raises an unrecoverable error within an Orion-related subsystem,
/// and stops execution. Do not call this outside Orion code.
///
/// The default behavior is to forward all arguments to `fatalError`.
/// This behavior can be modified using `updateOrionErrorHandler(_:)`.
///
/// - Warning: This function is thread-safe but not reentrant. Do
/// not call `orionError(_:file:line:)` or `updateOrionErrorHandler(_:)`
/// inside the `message` autoclosure.
///
/// - Parameter message: The error message.
///
/// - Parameter file: The file name associated with the error. Defaults
/// to the file in which `orionError(_:file:line:)` was called.
///
/// - Parameter line: The line number associated with the error.
/// Defaults to the line number on which `orionError(_:file:line:)` was
/// called.
public func orionError(
    _ message: @autoclosure () -> String,
    file: StaticString = #file,
    line: UInt = #line
) -> Never {
    errorHandlerQueue.sync {
        orionErrorHandler(message(), file, line)
    }
}

@inlinable func alwaysFalse() -> Bool { false }

/// Disables a spurious warning emitted by the Swift compiler in
/// hooked methods that call their original implementations.
///
/// When the glue file has not been compiled, Swift warns that
/// calls to `orig.foo()` will always recurse. We, however, know
/// that the glue file _will_ eventually be compiled and so the
/// warning is incorrect. This method suppresses that warning.
///
/// Since the function is `@_transparent`, Swift includes the
/// `orionError(...)` path in its control flow analysis of the caller,
/// which causes Swift to think that there is indeed a non-recursive
/// path for the function, suppressing the warning. Furthermore, since
/// `alwaysFalse()` isn't transparent, Swift doesn't go deep enough
/// while computing the warning to realize that the branch will never
/// execute, however the optimizer does indeed see this since the code
/// is still inlined, and therefore the method call is entirely
/// optimized out.
@_transparent @inlinable func disableRecursionCheck() {
    if alwaysFalse() {
        orionError("should never be executed")
    }
}

// TODO: Use this

// usage: someOptional !! "Error message"
infix operator !!: CastingPrecedence

extension Optional {
    @inlinable static func !! (lhs: Self, message: @autoclosure () -> String) -> Wrapped {
        switch lhs {
        case .some(let unwrapped):
            return unwrapped
        case .none:
            orionError(message())
        }
    }
}
