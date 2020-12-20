import Foundation

@inlinable
public func _indirectFatalError(
    _ message: @autoclosure () -> String = "",
    file: StaticString = #file,
    line: UInt = #line
) -> Never {
    fatalError(message(), file: file, line: line)
}
