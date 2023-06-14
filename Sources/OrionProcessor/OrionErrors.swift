import Foundation
import SwiftDiagnostics

// if this is caught, the caller should simply abort
public struct OrionFailure: Error {}

struct OrionDiagnostic: Error, LocalizedError, DiagnosticMessage {
    let id: String
    let message: String
    let severity: DiagnosticSeverity
    var errorDescription: String? { message }

    var diagnosticID: MessageID {
        MessageID(domain: "Orion", id: "\(type(of: self)).\(id)")
    }

    private init(id: String = #function, _ message: String, severity: DiagnosticSeverity = .warning) {
        self.id = id
        self.message = message
        self.severity = severity
    }

    fileprivate static func error(id: String = #function, _ message: String) -> Self {
        self.init(id: id, message, severity: .error)
    }

    fileprivate static func warning(id: String = #function, _ message: String) -> Self {
        self.init(id: id, message, severity: .warning)
    }

    fileprivate static func note(id: String = #function, _ message: String) -> Self {
        self.init(id: id, message, severity: .note)
    }
}

struct OrionFixIt: FixItMessage {
    let message: String
    private let messageID: String

    /// This should only be called within a static var on FixItMessage, such
    /// as the examples below. This allows us to pick up the messageID from the
    /// var name.
    fileprivate init(_ message: String, messageID: String = #function) {
        self.message = message
        self.messageID = messageID
    }

    var fixItID: MessageID {
        MessageID(domain: "Orion", id: "\(type(of: self)).\(messageID)")
    }
}

struct OrionNote: NoteMessage {
    let message: String
    private let messageID: String

    /// This should only be called within a static var on FixItMessage, such
    /// as the examples below. This allows us to pick up the messageID from the
    /// var name.
    fileprivate init(_ message: String, messageID: String = #function) {
        self.message = message
        self.messageID = messageID
    }

    var fixItID: MessageID {
        MessageID(domain: "Orion", id: "\(type(of: self)).\(messageID)")
    }
}

extension DiagnosticMessage where Self == OrionDiagnostic {
    // MARK: Directives

    static var unusedDirective: Self {
        .warning("Unused directive")
    }

    static func unknownDirective(_ name: String) -> Self {
        .warning("Unknown Orion directive: \(name)")
    }

    static func directiveParsing(_ error: String) -> Self {
        .warning("Failed to parse directive: \(error)")
    }

    static func badReturnsRetainedArity(_ count: Int) -> Self {
        .warning("returns_retained directive expected one argument, got \(count)")
    }

    static func badReturnsRetainedMode(_ mode: String) -> Self {
        .warning("Invalid returns_retained directive mode '\(mode)'")
    }

    static func newArity(_ count: Int) -> Self {
        .warning("new directive expected zero arguments, got \(count)")
    }

    static func disableArity(_ count: Int) -> Self {
        .warning("disable directive expected zero arguments, got \(count)")
    }

    static func suprTrampArity(_ count: Int) -> Self {
        .warning("supr_tramp directive expected zero arguments, got \(count)")
    }

    static func ignoreImportArity(_ count: Int) -> Self {
        .warning("ignore_import directive expected zero arguments, got \(count)")
    }

    // MARK: Parsing

    static var multipleTweaks: Self {
        .error("Cannot have more than one Tweak type in a module")
    }

    static func invalidDeclAccess(declKind: String) -> Self {
        .error("A \(declKind) cannot be private, fileprivate, or final")
    }

    static func staticClassMethodDecl() -> Self {
        .error(
            """
            A method hook/addition cannot be static. If you are hooking/adding a class \
            method, use `class` instead of `static`. If this is a helper function, declare \
            it as private or fileprivate.
            """
        )
    }

    static func finalClassMethodDecl() -> Self {
        .error(
            """
            A method hook/addition cannot be declared with the modifier final. If you intended \
            to mark this method as an addition, add the directive `// orion:new` above the \
            declaration instead.
            """
        )
    }

    static func multipleDecls() -> Self {
        .error("A type can only be a single type of hook or tweak")
    }

    static func functionHookWithoutFunction() -> Self {
        .error("Function hooks must contain a function named 'function'")
    }

    static func invalidFunctionHookModifiers() -> Self {
        .error(
            """
            A function hook's `function` cannot be declared with the modifiers private, \
            fileprivate, final, class, or static
            """
        )
    }

    static func classDeinit() -> Self {
        .error("A deinitializer cannot be a class method")
    }

    static func commentParseIssue() -> Self {
        .warning("Could not parse comment for directives")
    }
}

extension FixItMessage where Self == OrionFixIt {
    static var replaceWithClass: Self {
        .init("Replace with 'class'")
    }

    static var removeClass: Self {
        .init("Remove 'class'")
    }

    static var removeModifier: Self {
        .init("Remove modifier")
    }
}

extension NoteMessage where Self == OrionNote {
    static var duplicateTweak: Self {
        .init("Also declared here")
    }
}
