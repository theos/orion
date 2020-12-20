import Foundation

/// Raises a fatal error with a level of indirection. Do not rely
/// on this method; use `fatalError`.
@inlinable
public func _indirectFatalError(
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file,
    line: UInt = #line
) -> Never {
    fatalError(message(), file: file, line: line)
}
