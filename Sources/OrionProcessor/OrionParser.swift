import Foundation
import SwiftParser

public struct OrionParser {
    public struct Options {
        public let schema: Set<String>

        public init(schema: Set<String> = []) {
            self.schema = schema
        }
    }

    private let source: String
    private let fileName: String
    private let engine: OrionDiagnosticEngine
    private let options: Options

    public init(file: URL, diagnosticEngine: OrionDiagnosticEngine = .init(), options: Options = .init()) async throws {
        let (data, _) = try await URLSession.shared.data(from: file)
        let contents = String(decoding: data, as: UTF8.self)
        self.init(contents: contents, fileName: file.relativePath, diagnosticEngine: diagnosticEngine, options: options)
    }

    public init(contents: String, fileName: String, diagnosticEngine: OrionDiagnosticEngine = .init(), options: Options = .init()) {
        self.source = contents
        self.fileName = fileName
        self.engine = diagnosticEngine
        self.options = options
    }

    public func parse() async throws -> OrionData {
        let syntax = Parser.parse(source: source)
        let context = engine.createContext(for: syntax, fileName: fileName)
        let visitor = OrionVisitor(context: context, options: options)
        visitor.walk(syntax)
        guard !visitor.didFail else {
            throw OrionFailure()
        }
        return visitor.data
    }

}
