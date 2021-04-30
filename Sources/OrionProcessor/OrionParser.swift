import Foundation
import SwiftSyntax

public final class OrionParser {

    public struct Options {
        public let schema: Set<String>

        public init(schema: Set<String> = []) {
            self.schema = schema
        }
    }

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

        var filename: String {
            switch self {
            case .file(let url): return url.relativePath
            case .contents: return "<unknown>"
            }
        }
    }

    public let engine: DiagnosticEngine
    public let options: Options
    private let source: Source

    public init(file: URL, diagnosticEngine: OrionDiagnosticEngine = .init(), options: Options = .init()) {
        source = .file(file)
        self.engine = diagnosticEngine.createEngine()
        self.options = options
    }

    public init(contents: String, diagnosticEngine: OrionDiagnosticEngine = .init(), options: Options = .init()) {
        source = .contents(contents)
        self.engine = diagnosticEngine.createEngine()
        self.options = options
    }

    public func parse() throws -> OrionData {
        let syntax = try source.parseSyntax(diagnosticEngine: engine)
        let converter = SourceLocationConverter(file: source.filename, tree: syntax)
        let visitor = OrionVisitor(diagnosticEngine: engine, sourceLocationConverter: converter, options: options)
        visitor.walk(syntax)
        guard !visitor.didFail else {
            throw OrionFailure()
        }
        return visitor.data
    }

}
