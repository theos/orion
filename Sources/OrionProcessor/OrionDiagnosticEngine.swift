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

public class OrionDiagnosticEngine {
    let engine = DiagnosticEngine()
    public init() {}

    public func addConsumer(_ consumer: OrionDiagnosticConsumer) {
        engine.addConsumer(consumer.consumer)
    }
}
