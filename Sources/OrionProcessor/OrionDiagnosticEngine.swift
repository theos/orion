import Foundation
import SwiftSyntax

// so that the user doesn't have to import SwiftSyntax if they want diagnostics
public enum OrionDiagnosticConsumer {
    public enum JSONOutputFormat {
        case url(URL)
        case stdout

        var consumer: DiagnosticConsumer {
            switch self {
            case .url(let url): return JSONDiagnosticConsumer(outputURL: url)
            case .stdout: return JSONDiagnosticConsumer()
            }
        }
    }

    case json(outputFormat: JSONOutputFormat)
    case printing
    case custom(DiagnosticConsumer)

    var consumer: DiagnosticConsumer {
        switch self {
        case .json(let outputFormat): return outputFormat.consumer
        case .printing: return PrintingDiagnosticConsumer()
        case .custom(let consumer): return consumer
        }
    }
}

// thread-safe abstraction around DiagnosticEngine
public class OrionDiagnosticEngine {
    private class MUXConsumer: DiagnosticConsumer {
        // this type pipes messages from many `DiagnosticEngine`s
        // to one OrionDiagnosticEngine
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
