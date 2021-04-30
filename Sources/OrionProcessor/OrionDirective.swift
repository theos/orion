import Foundation
import SwiftSyntax

/// A rule describing which names match this directive.
enum OrionDirectiveMatchRule {
    /// Match this exact name.
    case exact(String)

    /// Match the part before the colon in a name.
    case prefix(String)

    /// Custom match rule. Returns true iff the name matches.
    case custom((String) -> Bool)
}

protocol OrionDirective {
    static var matchRule: OrionDirectiveMatchRule { get }

    var base: OrionDirectiveBase { get }
    init(base: OrionDirectiveBase) throws
}

extension OrionDirective {
    func setUsed() {
        base.setUsed()
    }
}

final class OrionDirectiveBase: Hashable, Equatable {
    let name: String
    let arguments: [String]
    let location: SourceLocation
    fileprivate private(set) var isUsed = false

    fileprivate init(name: String, arguments: [String], location: SourceLocation) {
        self.name = name
        self.arguments = arguments
        self.location = location
    }

    func setUsed() {
        isUsed = true
    }

    func hash(into hasher: inout Hasher) {
        location.offset.hash(into: &hasher)
    }

    static func == (lhs: OrionDirectiveBase, rhs: OrionDirectiveBase) -> Bool {
        lhs.location.offset == rhs.location.offset
    }
}

struct OrionDirectiveDiagnostic: Error, LocalizedError {
    enum Severity {
        case warning
        case error
    }

    let message: String
    let severity: Severity
    var errorDescription: String? { message }

    init(_ message: String, severity: Severity = .warning) {
        self.message = message
        self.severity = severity
    }

    var diagnosticMessage: Diagnostic.Message {
        let severity: Diagnostic.Severity
        switch self.severity {
        case .error: severity = .error
        case .warning: severity = .warning
        }
        return .init(severity, message)
    }
}

final class OrionDirectiveParser {
    static let shared = OrionDirectiveParser()
    private static let prefix = "orion"

    private let exactMap: [String: OrionDirective.Type]
    private let prefixMap: [String: OrionDirective.Type]
    private let customList: [(String) -> OrionDirective.Type?]

    // using a set here has the benefit of uniquing directives by location
    private var allBases: Set<OrionDirectiveBase> = []

    private init() {
        let types = OrionDirectives.all
        var exactMap: [String: OrionDirective.Type] = [:]
        var prefixMap: [String: OrionDirective.Type] = [:]
        var customList: [(String) -> OrionDirective.Type?] = []
        for type in types {
            switch type.matchRule {
            case .exact(let exact):
                exactMap[exact] = type
            case .prefix(let prefix):
                prefixMap[prefix] = type
            case .custom(let predicate):
                customList.append { predicate($0) ? type : nil }
            }
        }
        self.exactMap = exactMap
        self.prefixMap = prefixMap
        self.customList = customList
    }

    private func type(matching name: String) -> OrionDirective.Type? {
        guard !name.isEmpty else { return nil }
        if let type = exactMap[name] { return type }
        let prefix = String(name.split(separator: ":")[0])
        if let type = prefixMap[prefix] { return type }
        return customList.lazy.compactMap { $0(name) }.first
    }

    func directive(from text: String, at location: SourceLocation, schema: Set<String> = []) throws -> OrionDirective? {
        guard text.hasPrefix(Self.prefix) else { return nil }
        let dropped = text.dropFirst(Self.prefix.count)
        // directives can be of the form `orion:foo` or `orion[mySchema]:foo`.
        // check which form it is, and if it's the latter then only parse
        // the directive if the schema is within our enabled schema set.
        let body: Substring // the `foo` bit
        switch dropped.first {
        case ":":
            body = dropped.dropFirst()
        case "[":
            let withoutOpening = dropped.dropFirst() // mySchema]:foo
            guard let endIdx = withoutOpening.firstIndex(of: "]")
            else { return nil }
            let textSchema = withoutOpening[..<endIdx] // mySchema
            guard schema.contains(String(textSchema)) else { return nil }
            let afterSchema = withoutOpening[endIdx...] // ]:foo
            guard afterSchema.hasPrefix("]:") else { return nil }
            body = afterSchema.dropFirst(2)
        default:
            return nil
        }
        let parts = body.split(separator: " ")
        guard let name = parts.first.map(String.init) else { return nil }
        let arguments = parts.dropFirst().map(String.init)
        guard let matched = type(matching: name) else {
            throw OrionDirectiveDiagnostic("Unknown Orion directive: \(name)")
        }
        let base = OrionDirectiveBase(name: name, arguments: arguments, location: location)
        let result = allBases.insert(base)
        do {
            return try matched.init(base: result.memberAfterInsert)
        } catch {
            // if the init failed and this base wasn't previously in allBases
            // then remove the newly inserted value since it's okay if it's
            // unused, because the try will emit an error anyway
            if result.inserted { allBases.remove(base) }
            throw error
        }
    }

    func unusedDirectiveBases() -> [OrionDirectiveBase] {
        allBases.filter { !$0.isUsed }
    }
}

enum OrionDirectives {
    static let all: [OrionDirective.Type] = [
        ReturnsRetained.self,
        New.self,
        Disable.self,
        SuprTramp.self,
        IgnoreImport.self,
    ]

    struct ReturnsRetained: OrionDirective {
        enum Mode: String {
            case retained = "true"
            case notRetained = "false"
        }

        static let matchRule: OrionDirectiveMatchRule = .exact("returns_retained")

        let base: OrionDirectiveBase
        let mode: Mode
        init(base: OrionDirectiveBase) throws {
            self.base = base
            guard base.arguments.count == 1 else {
                throw OrionDirectiveDiagnostic("returns_retained directive expected one argument, got \(base.arguments.count)")
            }
            let rawMode = base.arguments[0]
            guard let mode = Mode(rawValue: rawMode) else {
                throw OrionDirectiveDiagnostic("Invalid returns_retained directive mode '\(rawMode)'")
            }
            self.mode = mode
        }
    }

    struct New: OrionDirective {
        static let matchRule: OrionDirectiveMatchRule = .exact("new")

        let base: OrionDirectiveBase
        init(base: OrionDirectiveBase) throws {
            self.base = base
            guard base.arguments.isEmpty else {
                throw OrionDirectiveDiagnostic("new directive expected zero arguments, got \(base.arguments.count)")
            }
        }
    }

    struct Disable: OrionDirective {
        static let matchRule: OrionDirectiveMatchRule = .exact("disable")

        let base: OrionDirectiveBase
        init(base: OrionDirectiveBase) throws {
            self.base = base
            guard base.arguments.isEmpty else {
                throw OrionDirectiveDiagnostic("disable directive expected zero arguments, got \(base.arguments.count)")
            }
        }
    }

    struct SuprTramp: OrionDirective {
        static let matchRule: OrionDirectiveMatchRule = .exact("supr_tramp")

        let base: OrionDirectiveBase
        init(base: OrionDirectiveBase) throws {
            self.base = base
            guard base.arguments.isEmpty else {
                throw OrionDirectiveDiagnostic("supr_tramp directive expected zero arguments, got \(base.arguments.count)")
            }
        }
    }

    struct IgnoreImport: OrionDirective {
        static let matchRule: OrionDirectiveMatchRule = .exact("ignore_import")

        let base: OrionDirectiveBase
        init(base: OrionDirectiveBase) throws {
            self.base = base
            guard base.arguments.isEmpty else {
                throw OrionDirectiveDiagnostic("ignore_import directive expected zero arguments, got \(base.arguments.count)")
            }
        }
    }
}
