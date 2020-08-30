import Foundation
import SwiftSyntax

public enum DiagnosticConsumerKind {
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

public final class LogosParser {

    private enum Source {
        case file(URL)
        case contents(String)

        func parseSyntax(diagnosticEngine: DiagnosticEngine? = nil) throws -> SourceFileSyntax {
            switch self {
            case .file(let url):
                return try SyntaxParser.parse(url, diagnosticEngine: diagnosticEngine)
            case .contents(let contents):
                return try SyntaxParser.parse(source: contents, diagnosticEngine: diagnosticEngine)
            }
        }
    }

    private let diagnosticEngine = DiagnosticEngine()
    private let source: Source

    public init(file: URL) {
        source = .file(file)
    }

    public init(contents: String) {
        source = .contents(contents)
    }

    public func addDiagnosticConsumer(kind consumerKind: DiagnosticConsumerKind) {
        diagnosticEngine.addConsumer(consumerKind.consumer)
    }

    public func parse() throws -> LogosData {
        let syntax = try source.parseSyntax(diagnosticEngine: diagnosticEngine)
        let visitor = LogosVisitor()
        visitor.walk(syntax)
        guard !visitor.didFail else {
            throw LogosFailure()
        }
        return visitor.data
    }

}
