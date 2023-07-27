import Foundation
import SwiftSyntax
#if swift(>=5.6)
import SwiftSyntaxParser

public typealias Diagnostic = SwiftSyntaxParser.Diagnostic

// DiagnosticEngine was removed in 5.6+. We re-introduce the
// required API surface for compatibility
//
// https://github.com/apple/swift-syntax/commit/198582f1009890eee38050c6d73bc0ed1cabd87b

public protocol DiagnosticConsumer {
    var needsLineColumn: Bool { get }
    func handle(_ diagnostic: Diagnostic)
    func finalize()
}
extension DiagnosticConsumer {
    public var needsLineColumn: Bool { true }
}

public final class DiagnosticEngine {
    private var consumers: [DiagnosticConsumer] = []
    private(set) var diagnostics: [Diagnostic] = []

    init() {}

    func addConsumer(_ consumer: DiagnosticConsumer) {
        consumers.append(consumer)
        // Start the consumer with all previous diagnostics.
        for diagnostic in diagnostics {
            consumer.handle(diagnostic)
        }
    }

    func diagnose(_ diagnostic: Diagnostic) {
        diagnostics.append(diagnostic)
        for consumer in consumers {
            consumer.handle(diagnostic)
        }
    }

    func diagnose(
        _ message: Diagnostic.Message,
        location: SourceLocation? = nil,
        actions: ((inout Diagnostic.Builder) -> Void)? = nil
    ) {
        diagnose(Diagnostic(message: message, location: location, actions: actions))
    }
}

public class PrintingDiagnosticConsumer: DiagnosticConsumer {
    public init() {}

    func write<T: CustomStringConvertible>(_ msg: T) {
        FileHandle.standardError.write("\(msg)".data(using: .utf8)!)
    }

    /// Prints the contents of a diagnostic to stderr.
    public func handle(_ diagnostic: Diagnostic) {
        write(diagnostic)
        for note in diagnostic.notes {
            write(note.asDiagnostic())
        }
    }

    /// Prints each of the fields in a diagnositic to stderr.
    public func write(_ diagnostic: Diagnostic) {
        if let loc = diagnostic.location {
            write("\(loc.file!):\(loc.line!):\(loc.column!): ")
        } else {
            write("<unknown>:0:0: ")
        }
        switch diagnostic.message.severity {
        case .note: write("note: ")
        case .warning: write("warning: ")
        case .error: write("error: ")
        }
        write(diagnostic.message.text)
        write("\n")

        // TODO: Write original file contents out and highlight them.
    }

    public func finalize() {}
}

typealias SyntaxParser = SwiftSyntaxParser.SyntaxParser

extension SyntaxParser {

    public static func parse(
        _ url: URL,
        diagnosticEngine: DiagnosticEngine? = nil
    ) throws -> SourceFileSyntax {
        try parse(url, diagnosticHandler: diagnosticEngine?.diagnose)
    }

    public static func parse(
        source: String,
        parseTransition: IncrementalParseTransition? = nil,
        filenameForDiagnostics: String = "",
        diagnosticEngine: DiagnosticEngine? = nil
    ) throws -> SourceFileSyntax {
        try parse(
            source: source,
            parseTransition: parseTransition,
            filenameForDiagnostics: filenameForDiagnostics,
            diagnosticHandler: diagnosticEngine?.diagnose
        )
    }

}
#endif

// so that the user doesn't have to import SwiftSyntax if they want diagnostics
public enum OrionDiagnosticConsumer {
    case printing
    case custom(DiagnosticConsumer)

    var consumer: DiagnosticConsumer {
        switch self {
        case .printing: return PrintingDiagnosticConsumer()
        case .custom(let consumer): return consumer
        }
    }
}

// thread-safe abstraction around DiagnosticEngine
public class OrionDiagnosticEngine {
    private class MUXConsumer: DiagnosticConsumer {
        // this type pipes messages from many `DiagnosticEngine`s
        // to one OrionDiagnosticEngine. We maintain a strong ref
        // to the Orion engine to ensure that it isn't deinit'd
        // until all of its child `DiagnosticEngine`s are.
        let engine: OrionDiagnosticEngine
        init(engine: OrionDiagnosticEngine) {
            self.engine = engine
        }
        var needsLineColumn: Bool { engine.needsLineColumn }
        func handle(_ diagnostic: Diagnostic) { engine.handle(diagnostic) }
        func finalize() {}
    }

    private let consumerQueue = DispatchQueue(label: "consumer-queue")
    private var consumers: [DiagnosticConsumer] = []
    public init() {}

    // it might be possible to make this not require synchronization by using
    // atomics, but there's no easy way to do that in Swift yet short of importing
    // the Swift Atomics package, which would add yet another dependency
    private var _needsLineColumn = false
    private var needsLineColumn: Bool {
        consumerQueue.sync { _needsLineColumn }
    }

    public func addConsumer(_ consumer: OrionDiagnosticConsumer) {
        let newConsumer = consumer.consumer
        consumerQueue.sync {
            consumers.append(newConsumer)
            if newConsumer.needsLineColumn {
                // it doesn't really matter what the old value was
                _needsLineColumn = true
            }
        }
    }

    private func handle(_ diagnostic: Diagnostic) {
        consumerQueue.sync {
            consumers.forEach { $0.handle(diagnostic) }
        }
    }

    func createEngine() -> DiagnosticEngine {
        let engine = DiagnosticEngine()
        engine.addConsumer(MUXConsumer(engine: self))
        return engine
    }

    deinit {
        let diagnostics = OrionDirectiveParser.shared.unusedDirectiveBases().map { dir -> Diagnostic in
            dir.setUsed() // so that future calls don't complain about the same directives
            return Diagnostic(message: .init(.warning, "Unused directive"), location: dir.location, actions: nil)
        }
        consumerQueue.sync {
            diagnostics.forEach { d in
                consumers.forEach { $0.handle(d) }
            }
            consumers.forEach { $0.finalize() }
        }
    }
}
