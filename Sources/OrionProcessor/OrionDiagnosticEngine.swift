import Foundation
import SwiftSyntax
import SwiftDiagnostics

/// A diagnostic engine that emits to a single file.
///
/// Thread safe.
public struct OrionSourceContext {
    let engine: OrionDiagnosticEngine
    let converter: SourceLocationConverter

    func diagnose(_ diagnostic: Diagnostic) {
        engine.diagnose(diagnostic)
    }
}

public protocol OrionDiagnosticConsumer {
    mutating func register(source: SourceFileSyntax, name: String)
    mutating func diagnose(_ diagnostic: Diagnostic)
    func finalize()
}

extension OrionDiagnosticConsumer {
    public mutating func register(source: SourceFileSyntax, name: String) {}
    public func finalize() {}
}

public class OrionDiagnosticEngine {
    private let queue = DispatchQueue(label: "consumer-queue")

    public var consumers: [any OrionDiagnosticConsumer] = []

    public init() {}

    public func addConsumer(_ consumer: some OrionDiagnosticConsumer) {
        queue.sync { consumers.append(consumer) }
    }

    public func diagnose(_ diagnostic: Diagnostic) {
        queue.sync {
            for index in consumers.indices {
                consumers[index].diagnose(diagnostic)
            }
        }
    }

    func createContext(for source: SourceFileSyntax, fileName: String) -> OrionSourceContext {
        queue.sync {
            for index in consumers.indices {
                consumers[index].register(source: source, name: fileName)
            }
        }
        let converter = SourceLocationConverter(file: fileName, tree: source)
        return OrionSourceContext(engine: self, converter: converter)
    }

    func finalize() {
        for dir in OrionDirectiveParser.shared.unusedDirectiveBases() {
            dir.setUsed() // so that future calls don't complain about the same directives
            diagnose(Diagnostic(
                node: dir.syntax,
                position: .init(utf8Offset: dir.location.offset),
                message: .unusedDirective
            ))
        }
        queue.sync {
            for consumer in consumers {
                consumer.finalize()
            }
            consumers.removeAll()
        }
    }

    deinit {
        finalize()
    }
}

public struct XcodeDiagnosticConsumer: OrionDiagnosticConsumer {
    private var converters: [SourceFileSyntax: SourceLocationConverter] = [:]

    public init() {}

    public mutating func register(source: SourceFileSyntax, name: String) {
        converters[source] = .init(file: name, tree: Syntax(source))
    }

    public func diagnose(_ diagnostic: Diagnostic) {
        let root = diagnostic.node.root.as(SourceFileSyntax.self)
        let converter = root.flatMap { converters[$0] }
        let prefix = if let loc = converter?.location(for: diagnostic.position) {
            "\(loc.file):\(loc.line):\(loc.column)"
        } else {
            "<unknown>:0:0"
        }
        print("\(prefix): \(diagnostic.diagMessage.severity): \(diagnostic.message)", to: &.standardError)
    }
}

extension OrionDiagnosticConsumer where Self == XcodeDiagnosticConsumer {
    public static var xcode: Self { .init() }
}

public struct PrettyDiagnosticConsumer: OrionDiagnosticConsumer {
    private var diagnostics: [SourceFileSyntax: (String, [Diagnostic])] = [:]

    public init() {}

    public mutating func register(source: SourceFileSyntax, name: String) {
        diagnostics[source] = (name, [])
    }

    public mutating func diagnose(_ diagnostic: Diagnostic) {
        if let root = diagnostic.node.root.as(SourceFileSyntax.self) {
            diagnostics[root]?.1.append(diagnostic)
        }
    }

    public func finalize() {
        var group = GroupedDiagnostics()
        for (file, (name, diags)) in diagnostics where !diags.isEmpty {
            group.addSourceFile(tree: file, displayName: name, diagnostics: diags)
        }
        print(DiagnosticsFormatter.annotateSources(in: group), terminator: "", to: &.standardError)
    }
}

extension OrionDiagnosticConsumer where Self == PrettyDiagnosticConsumer {
    public static var pretty: Self { .init() }
}

struct FileHandleOutputStream: TextOutputStream {
    let handle: FileHandle
    func write(_ string: String) {
        handle.write(Data(string.utf8))
    }
}

extension TextOutputStream where Self == FileHandleOutputStream {
    static var standardOutput: Self {
        get { .init(handle: .standardOutput) }
        set {}
    }
    static var standardError: Self {
        get { .init(handle: .standardError) }
        set {}
    }
}
