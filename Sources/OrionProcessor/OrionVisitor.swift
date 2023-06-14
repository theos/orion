import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

// it do be like that for compiler stuff
// swiftlint:disable:next superfluous_disable_command
// swiftlint:disable type_body_length file_length

class OrionVisitor: SyntaxVisitor {
    private enum DeclarationKind: CustomStringConvertible {
        case classHook(target: Syntax)
        case functionHook
        case tweak(hasBackend: Bool)

        var description: String {
            switch self {
            case .classHook: return "class hook"
            case .functionHook: return "function hook"
            case .tweak: return "tweak"
            }
        }

        init?(typeIdentifier: SimpleTypeIdentifierSyntax) {
            let base = typeIdentifier.name.text
            switch base {
            case "ClassHook":
                guard let target = typeIdentifier.genericArgumentClause?.arguments.first?.argumentType else { return nil }
                self = .classHook(target: Syntax(target))
            case "FunctionHook":
                self = .functionHook
            case "Tweak":
                self = .tweak(hasBackend: false)
            case "TweakWithBackend":
                self = .tweak(hasBackend: true)
            default:
                return nil
            }
        }

        func isModifierInvalid(_ modifier: ModifierKind) -> Bool {
            switch self {
            case .classHook, .functionHook:
                return modifier.isUninheritable
            case .tweak:
                return modifier.isInaccessible
            }
        }
    }

    private enum ModifierKind: String {
        case `private`, `fileprivate`, `final`, `class`, `static`

        static let uninheritable: Set<ModifierKind> = [
            .private, .fileprivate, .final
        ]

        static let inaccessible: Set<ModifierKind> = [
            .private, .fileprivate
        ]

        static let invalidForFunctionHooks: Set<ModifierKind> = [
            .private, .fileprivate, .final, .class, .static
        ]

        init?(_ decl: DeclModifierSyntax) {
            self.init(rawValue: decl.name.text)
        }

        var isInaccessible: Bool { Self.inaccessible.contains(self) }
        var isUninheritable: Bool { Self.uninheritable.contains(self) }
        var isInvalidForFunctionHook: Bool { Self.invalidForFunctionHooks.contains(self) }
    }

    // don't consider these names as method hooks
    private static let ignoredMethodNames: Set<String> = [
        // these are the optional AnyHook protocol methods; don't treat them as hooks
        "hookWillActivate", "hookDidActivate"
    ]

    let context: OrionSourceContext
    let options: OrionParser.Options
    init(
        context: OrionSourceContext,
        options: OrionParser.Options
    ) {
        self.context = context
        self.options = options
        super.init(viewMode: .fixedUp)
    }

    private(set) var data = OrionData()
    private(set) var didFail = false

    private func makeDirectives(
        for trivia: Trivia,
        syntax: Syntax,
        position: AbsolutePosition,
        warnOnFailure: Bool = false
    ) -> [OrionDirective] {
        var currPos = position
        return trivia.compactMap { piece -> OrionDirective? in
            defer { currPos += piece.sourceLength }
            let location = context.converter.location(for: currPos)
            let directive: String
            switch piece {
            case .lineComment(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("//") else {
                    context.diagnose(.init(node: syntax, position: currPos, message: .commentParseIssue()))
                    return nil
                }
                directive = trimmed.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
            case .blockComment(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("/*") && trimmed.hasSuffix("*/") else {
                    context.diagnose(.init(node: syntax, position: currPos, message: .commentParseIssue()))
                    return nil
                }
                directive = trimmed.dropFirst(2).dropLast(2).trimmingCharacters(in: .whitespacesAndNewlines)
            default:
                return nil
            }
            do {
                return try OrionDirectiveParser.shared.directive(
                    from: directive, at: location, on: syntax, schema: options.schema
                )
            } catch let err as OrionDiagnostic {
                if warnOnFailure {
                    context.diagnose(.init(node: syntax, position: currPos, message: err))
                }
                return nil
            } catch {
                if warnOnFailure {
                    context.diagnose(.init(node: syntax, position: currPos, message: .directiveParsing("\(error)")))
                }
                return nil
            }
        }
    }

    // any comments between the last token *before* syntax, and the first token *of* syntax
    // are considered here
    private func makeDirectives(for syntax: Syntax, warnOnFailure: Bool = false) -> [OrionDirective] {
        let leading = makeDirectives(
            for: syntax.leadingTrivia,
            syntax: syntax,
            position: syntax.position,
            warnOnFailure: warnOnFailure
        )

        let prevTrailing: [OrionDirective]
        if let prev = syntax.previousToken(viewMode: .sourceAccurate) {
            prevTrailing = makeDirectives(
                for: prev.trailingTrivia,
                syntax: Syntax(prev),
                position: prev.endPositionBeforeTrailingTrivia,
                warnOnFailure: warnOnFailure
            )
        } else {
            prevTrailing = []
        }

        return prevTrailing + leading
    }

    private func makeFunction(for function: FunctionDeclSyntax) -> Syntax? {
        let paramList = function.signature.input.parameterList
        let elements = paramList.enumerated().compactMap { idx, element -> FunctionParameterSyntax? in
            var element = element
            if element.firstName.trailingTrivia.isEmpty {
                element.firstName.trailingTrivia = .space
            }
            element.secondName = .identifier("arg\(idx + 1)")
            return element
        }
        guard elements.count == paramList.count else { return nil }
        var function = function
        function = function.addModifier(DeclModifierSyntax(
            name: .identifier("override"),
            trailingTrivia: .space
        ))
        function.funcKeyword.leadingTrivia = []
        function.signature.input.parameterList = .init(elements)
        function.signature.output?.trailingTrivia = []
        function.body = nil
        return Syntax(function)
    }

    private func makeIdentifier(for function: FunctionDeclSyntax) -> Syntax? {
        let arguments = DeclNameArgumentListSyntax {
            for param in function.signature.input.parameterList {
                DeclNameArgumentSyntax(name: param.firstName.trimmed)
            }
        }
        return Syntax(
            arguments.isEmpty
            ? "\(function.identifier)" as ExprSyntax
            : "\(function.identifier)(\(arguments))" as ExprSyntax
        )
    }

    private enum FunctionKind {
        case function
        case method(firstType: String, returnsUnmanaged: Bool)
    }

    private func makeClosure(for function: FunctionDeclSyntax, kind: FunctionKind) -> Syntax? {
        let params = function.signature.input.parameterList
        let rawParamTypes = params.map(\.type)
        guard rawParamTypes.count == params.count else { return nil }

        let prefixTypes: [TypeSyntax]
        let returnsUnmanaged: Bool
        switch kind {
        case .function:
            prefixTypes = []
            returnsUnmanaged = false
        case .method(let firstType, let _returnsUnmanaged):
            prefixTypes = [
                "\(raw: firstType)",
                "Selector"
            ]
            returnsUnmanaged = _returnsUnmanaged
        }
        let types = prefixTypes + rawParamTypes

        let arguments = TupleTypeElementListSyntax {
            for type in types {
                TupleTypeElementSyntax(type: type)
            }
        }
        let rawReturnType =
            function.signature.output?.returnType.trimmed ??
            "Void"
        let returnType = returnsUnmanaged ? "Unmanaged<\(rawReturnType)>" : rawReturnType

        return Syntax("(\(arguments)) -> \(returnType)" as TypeSyntax)
    }

    private func orionFunction(for function: FunctionDeclSyntax) -> OrionData.Function? {
        guard let fn = makeFunction(for: function),
              let id = makeIdentifier(for: function),
              let closure = makeClosure(for: function, kind: .function)
        else { return nil }
        return OrionData.Function(
            numberOfArguments: function.signature.input.parameterList.count,
            function: fn,
            identifier: id,
            closure: closure,
            directives: makeDirectives(for: Syntax(function)),
            location: function.startLocation(converter: context.converter, afterLeadingTrivia: true)
        )
    }

    private func staticModifier(in function: FunctionDeclSyntax) -> DeclModifierSyntax? {
        function.modifiers?.first { ModifierKind($0) == .static }
    }

    private func classModifier(in function: FunctionDeclSyntax) -> DeclModifierSyntax? {
        function.modifiers?.first { ModifierKind($0) == .class }
    }

    private func functionObjCAttribute(_ function: FunctionDeclSyntax) -> OrionData.ClassHook.Method.ObjCAttribute? {
        guard let att = function.attributes?.lazy
                .compactMap({ $0.as(AttributeSyntax.self) })
                .first(where: { $0.attributeName.trimmedDescription == "objc" })
            else { return nil }
        if let arg = att.argument?.as(ObjCSelectorSyntax.self) {
            return .named(arg)
        } else {
            return .simple
        }
    }

    private func functionIsDeinitializer(_ function: FunctionDeclSyntax) -> Bool {
        function.identifier.text == "deinitializer"
    }

    private func availability(for node: ClassDeclSyntax) -> AvailabilitySpecListSyntax? {
        (node.attributes?.lazy
            .compactMap { $0.as(AttributeSyntax.self) }
            .first { $0.attributeName.trimmedDescription == "available" }?
            .argument).flatMap { $0.as(AvailabilitySpecListSyntax.self) }
    }

    private func handle(classHook node: ClassDeclSyntax, target: Syntax) {
        let methods = node.memberBlock.members
            .compactMap { FunctionDeclSyntax($0.decl) }
            .filter { (decl: FunctionDeclSyntax) -> Bool in
                guard let modifiers = decl.modifiers else { return true }
                // This allows users to use one of these declarations to add a helper function,
                // which isn't actually a hook, to a hook type
                return !modifiers.contains { ModifierKind($0)?.isInaccessible == true }
                    && !Self.ignoredMethodNames.contains(decl.identifier.text)
            }
            .filter { (decl: FunctionDeclSyntax) -> Bool in
                // Although if the method is `final` we could technically skip this check because
                // we don't need to inherit method additions, `static` and `final` aren't allowed
                // to co-exist anyway because static implies final. Swift recommends removing final
                // which would result in us not treating the method as an addition. And removing
                // static results in the method being an instance method instead of a class method.
                // Strictly disallowing static reduces confusion, making it clear that one should
                // use `class` instead of `static`.
                if let staticModifier = staticModifier(in: decl) {
                    context.diagnose(.init(node: Syntax(decl), message: .staticClassMethodDecl(), fixIts: [
                        .init(message: .replaceWithClass, changes: [.replace(
                            oldNode: Syntax(staticModifier.trimmed),
                            newNode: Syntax(TokenSyntax.keyword(.class))
                        )])
                    ]))
                    didFail = true
                    return false
                }
                if decl.modifiers?.contains(where: { ModifierKind($0) == .final }) == true {
                    context.diagnose(.init(node: Syntax(decl), message: .finalClassMethodDecl()))
                    didFail = true
                    return false
                }
                return true
            }
            .compactMap { (function: FunctionDeclSyntax) -> OrionData.ClassHook.Method? in
                let classModifier = self.classModifier(in: function)
                let isClass = classModifier != nil
                let isDeinit = functionIsDeinitializer(function)
                if isDeinit, let classModifier = classModifier {
                    context.diagnose(.init(
                        node: Syntax(classModifier),
                        message: .classDeinit(),
                        fixIts: [.init(message: .removeClass, changes: [.replace(
                            oldNode: Syntax(classModifier),
                            newNode: Syntax(MissingSyntax())
                        )])]
                    ))
                    didFail = true
                    return nil
                }
                guard let orionFn = orionFunction(for: function),
                      let methodClosure = makeClosure(
                        for: function,
                        kind: .method(firstType: isClass ? "AnyClass" : "Target", returnsUnmanaged: false)
                      ),
                      let methodClosureUnmanaged = makeClosure(
                        for: function,
                        kind: .method(firstType: isClass ? "AnyClass" : "Target", returnsUnmanaged: true)
                      ),
                      let superClosure = makeClosure(
                        for: function,
                        kind: .method(firstType: "UnsafeRawPointer", returnsUnmanaged: false)
                      ),
                      let superClosureUnmanaged = makeClosure(
                        for: function,
                        kind: .method(firstType: "UnsafeRawPointer", returnsUnmanaged: true)
                      )
                else { return nil }
                return OrionData.ClassHook.Method(
                    isClassMethod: isClass,
                    objcAttribute: functionObjCAttribute(function),
                    isDeinitializer: isDeinit,
                    function: orionFn,
                    methodClosure: methodClosure,
                    methodClosureUnmanaged: methodClosureUnmanaged,
                    superClosure: superClosure,
                    superClosureUnmanaged: superClosureUnmanaged
                )
            }
        data.classHooks.append(OrionData.ClassHook(
            name: node.identifier.text,
            target: target,
            methods: methods,
            availability: availability(for: node)
        ))
    }

    private func handle(functionHook node: ClassDeclSyntax) {
        guard let function = node.memberBlock.members
            .compactMap({ $0.decl.as(FunctionDeclSyntax.self) })
            .first(where: { $0.identifier.text == "function" })
            else {
                context.diagnose(.init(node: Syntax(node), message: .functionHookWithoutFunction()))
                didFail = true
                return
            }

        if let invalidModifiers = function.modifiers?.filter({
            ModifierKind($0)?.isInvalidForFunctionHook == true
        }), !invalidModifiers.isEmpty {
            context.diagnose(.init(node: Syntax(invalidModifiers[0]), message: .invalidFunctionHookModifiers()))
            didFail = true
            return
        }

        guard let orionFn = orionFunction(for: function) else { return }
        data.functionHooks.append(OrionData.FunctionHook(
            name: node.identifier.text,
            function: orionFn,
            availability: availability(for: node)
        ))
    }

    private func handle(tweak identifier: TokenSyntax, hasBackend: Bool) {
        data.tweaks.append(OrionData.Tweak(name: Syntax(identifier), hasBackend: hasBackend))
    }

    private func declarationKind(for node: TypeInheritanceClauseSyntax?, modifiers: ModifierListSyntax?) -> DeclarationKind? {
        guard let node = node else { return nil }

        let declarationKinds = node.inheritedTypeCollection
            .compactMap { $0.typeName.as(SimpleTypeIdentifierSyntax.self) }
            .compactMap(DeclarationKind.init(typeIdentifier:))

        switch declarationKinds.count {
        case 0: return nil
        case 1:
            let kind = declarationKinds[0]
            let uninheritable = modifiers?.filter { ModifierKind($0).map(kind.isModifierInvalid) == true } ?? []
            if !uninheritable.isEmpty {
                context.diagnose(.init(
                    node: Syntax(uninheritable[0]),
                    message: .invalidDeclAccess(declKind: "\(kind)"),
                    fixIts: uninheritable.map {
                        .init(message: .removeModifier, changes: [.replace(
                            oldNode: Syntax($0),
                            newNode: Syntax(MissingSyntax())
                        )])
                    }
                ))
                didFail = true
                return nil
            }
            return kind
        default:
            context.diagnose(.init(node: Syntax(node), message: .multipleDecls()))
            didFail = true
            return nil
        }
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        switch declarationKind(for: node.inheritanceClause, modifiers: node.modifiers) {
        case .tweak(let hasBackend):
            handle(tweak: node.identifier, hasBackend: hasBackend)
        case .classHook, .functionHook, nil:
            break
        }
    }

    override func visitPost(_ node: StructDeclSyntax) {
        switch declarationKind(for: node.inheritanceClause, modifiers: node.modifiers) {
        case .tweak(let hasBackend):
            handle(tweak: node.identifier, hasBackend: hasBackend)
        case .classHook, .functionHook, nil:
            break
        }
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        switch declarationKind(for: node.inheritanceClause, modifiers: node.modifiers) {
        case .tweak(let hasBackend):
            handle(tweak: node.identifier, hasBackend: hasBackend)
        case .classHook(let target):
            handle(classHook: node, target: target)
        case .functionHook:
            handle(functionHook: node)
        case nil:
            break
        }
    }

    override func visit(_ node: SourceFileSyntax) -> SyntaxVisitorContinueKind {
        let directives = makeDirectives(for: Syntax(node))
        if directives.contains(where: { $0 is OrionDirectives.Disable }) {
            // we just need to mark these first few directives as used
            // so that they don't emit warnings. Everything else will
            // be skipped anyway.
            directives.forEach { $0.setUsed() }
            return .skipChildren
        } else {
            // note that since OrionData types are merged before being passed
            // to the generator, this means global directives are truly *global*
            // and not per-file
            data.globalDirectives += directives
            return .visitChildren
        }
    }

    override func visitPost(_ node: ImportDeclSyntax) {
        let directives = makeDirectives(for: Syntax(node))
        let ignoreImports = directives.filter { $0 is OrionDirectives.IgnoreImport }
        guard ignoreImports.isEmpty else {
            ignoreImports.forEach { $0.setUsed() }
            return
        }
        data.imports.append(node.trimmed)
    }

    override func visitPost(_ node: TokenSyntax) {
        // validates syntax of all directives and registers them
        // for "unused directive" warnings as well
        _ = makeDirectives(for: Syntax(node), warnOnFailure: true)
    }
}
