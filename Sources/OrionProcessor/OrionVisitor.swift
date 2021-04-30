import Foundation
import SwiftSyntax

// it do be like that for compiler stuff
// swiftlint:disable:next superfluous_disable_command
// swiftlint:disable type_body_length file_length

#if swift(>=5.4)
private extension SyntaxFactory {
    static func makeFunctionType(
        leftParen: TokenSyntax,
        arguments: TupleTypeElementListSyntax,
        rightParen: TokenSyntax,
        throwsOrRethrowsKeyword: TokenSyntax?,
        arrow: TokenSyntax,
        returnType: TypeSyntax
    ) -> FunctionTypeSyntax {
        makeFunctionType(
            leftParen: leftParen,
            arguments: arguments,
            rightParen: rightParen,
            asyncKeyword: nil,
            throwsOrRethrowsKeyword: throwsOrRethrowsKeyword,
            arrow: arrow,
            returnType: returnType
        )
    }
}
#endif

private extension Diagnostic.Message {
    static func invalidDeclAccess(declKind: String) -> Diagnostic.Message {
        .init(.error, "A \(declKind) cannot be private, fileprivate, or final")
    }
    static func staticClassMethodDecl() -> Diagnostic.Message {
        .init(
            .error,
            """
            A method hook/addition cannot be static. If you are hooking/adding a class \
            method, use `class` instead of `static`. If this is a helper function, declare \
            it as private or fileprivate.
            """
        )
    }
    static func finalClassMethodDecl() -> Diagnostic.Message {
        .init(
            .error,
            """
            A method hook/addition cannot be declared with the modifier final. If you intended \
            to mark this method as an addition, add the directive `// orion:new` above the \
            declaration instead.
            """
        )
    }
    static func multipleDecls() -> Diagnostic.Message {
        .init(.error, "A type can only be a single type of hook or tweak")
    }
    static func functionHookWithoutFunction() -> Diagnostic.Message {
        .init(.error, "Function hooks must contain a function named 'function'")
    }
    static func invalidFunctionHookModifiers() -> Diagnostic.Message {
        .init(
            .error,
            """
            A function hook's `function` cannot be declared with the modifiers private, \
            fileprivate, final, class, or static
            """
        )
    }
    static func classDeinit() -> Diagnostic.Message {
        .init(.error, "A deinitializer cannot be a class method")
    }
    static func commentParseIssue() -> Diagnostic.Message {
        .init(.warning, "Could not parse comment for directives")
    }
}

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

    let options: OrionParser.Options
    let converter: SourceLocationConverter
    let diagnosticEngine: DiagnosticEngine
    init(
        diagnosticEngine: DiagnosticEngine,
        sourceLocationConverter: SourceLocationConverter,
        options: OrionParser.Options
    ) {
        self.diagnosticEngine = diagnosticEngine
        self.converter = sourceLocationConverter
        self.options = options
    }

    private(set) var data = OrionData()
    private(set) var didFail = false

    private func makeDirectives(
        for trivia: Trivia,
        position: AbsolutePosition,
        warnOnFailure: Bool = false
    ) -> [OrionDirective] {
        var currPos = position
        return trivia.compactMap { piece in
            defer { currPos += piece.sourceLength }
            let location = converter.location(for: currPos)
            let directive: String
            switch piece {
            case .lineComment(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("//") else {
                    diagnosticEngine.diagnose(.commentParseIssue(), location: location)
                    return nil
                }
                directive = trimmed.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
            case .blockComment(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("/*") && trimmed.hasSuffix("*/") else {
                    diagnosticEngine.diagnose(.commentParseIssue(), location: location)
                    return nil
                }
                directive = trimmed.dropFirst(2).dropLast(2).trimmingCharacters(in: .whitespacesAndNewlines)
            default:
                return nil
            }
            do {
                return try OrionDirectiveParser.shared.directive(from: directive, at: location, schema: options.schema)
            } catch let err as OrionDirectiveDiagnostic {
                if warnOnFailure {
                    diagnosticEngine.diagnose(err.diagnosticMessage, location: location)
                }
                return nil
            } catch {
                if warnOnFailure {
                    diagnosticEngine.diagnose(Diagnostic.Message(.error, "\(error)"), location: location)
                }
                return nil
            }
        }
    }

    // any comments between the last token *before* syntax, and the first token *of* syntax
    // are considered here
    private func makeDirectives(for syntax: Syntax, warnOnFailure: Bool = false) -> [OrionDirective] {
        let leading: [OrionDirective]
        if let trivia = syntax.leadingTrivia {
            leading = makeDirectives(
                for: trivia,
                position: syntax.position,
                warnOnFailure: warnOnFailure
            )
        } else {
            leading = []
        }

        let prevTrailing: [OrionDirective]
        if let prev = syntax.previousToken, let trivia = prev.trailingTrivia {
            prevTrailing = makeDirectives(
                for: trivia,
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
            guard let name = element.firstName else { return nil }
            if name.trailingTrivia.isEmpty {
                element = element.withFirstName(element.firstName?.withTrailingTrivia(.spaces(1)))
            }
            return element.withSecondName(SyntaxFactory.makeIdentifier("arg\(idx + 1)"))
        }
        guard elements.count == paramList.count else { return nil }
        let input = function.signature.input.withParameterList(SyntaxFactory.makeFunctionParameterList(elements))
        let signature = function.signature.withInput(input).withOutput(function.signature.output?.withoutTrailingTrivia())
        let function2 = function.withoutTrivia().withSignature(signature)
            .addModifier(
                // we have to do this here: we can't simply prefix the func with "override" because
                // it may have attributes, and we'll end up putting override before the attributes,
                // whereas modifiers need to come after the attributes
                SyntaxFactory.makeDeclModifier(
                    name: SyntaxFactory.makeIdentifier("override"),
                    detailLeftParen: nil, detail: nil, detailRightParen: nil
                ).withTrailingTrivia(.spaces(1))
            )
            .withBody(SyntaxFactory.makeBlankCodeBlock())
            .withFuncKeyword(function.funcKeyword.withoutLeadingTrivia())
        return Syntax(function2)
    }

    private func makeIdentifier(for function: FunctionDeclSyntax) -> Syntax? {
        let declNameArguments: DeclNameArgumentsSyntax?

        let params = function.signature.input.parameterList
        if params.isEmpty {
            declNameArguments = nil
        } else {
            let params = function.signature.input.parameterList
            let argumentsArray = params.compactMap { param -> DeclNameArgumentSyntax? in
                guard let firstName = param.firstName, let colon = param.colon else { return nil }
                return SyntaxFactory.makeDeclNameArgument(
                    name: firstName.withoutTrivia(), colon: colon.withoutTrivia()
                )
            }
            guard argumentsArray.count == params.count else { return nil }
            declNameArguments = SyntaxFactory.makeDeclNameArguments(
                leftParen: SyntaxFactory.makeLeftParenToken(),
                arguments: SyntaxFactory.makeDeclNameArgumentList(argumentsArray),
                rightParen: SyntaxFactory.makeRightParenToken()
            )
        }

        return Syntax(SyntaxFactory.makeIdentifierExpr(identifier: function.identifier, declNameArguments: declNameArguments))
    }

    private enum FunctionKind {
        case function
        case method(firstType: String, returnsUnmanaged: Bool)
    }

    private func makeClosure(for function: FunctionDeclSyntax, kind: FunctionKind) -> Syntax? {
        let params = function.signature.input.parameterList
        let rawParamTypes = params.compactMap { $0.type }
        guard rawParamTypes.count == params.count else { return nil }

        let prefixTypes: [TypeSyntax]
        let returnsUnmanaged: Bool
        switch kind {
        case .function:
            prefixTypes = []
            returnsUnmanaged = false
        case .method(let firstType, let _returnsUnmanaged):
            prefixTypes = [
                SyntaxFactory.makeTypeIdentifier(firstType),
                SyntaxFactory.makeTypeIdentifier("Selector")
            ]
            returnsUnmanaged = _returnsUnmanaged
        }
        let types = prefixTypes + rawParamTypes

        let last = types.last
        let argumentsArray = types.map { type in
            SyntaxFactory.makeTupleTypeElement(
                type: type,
                trailingComma: type == last ? nil : SyntaxFactory.makeCommaToken().withTrailingTrivia(.spaces(1))
            )
        }
        let arguments = SyntaxFactory.makeTupleTypeElementList(argumentsArray)
        let rawReturnType =
            function.signature.output?.returnType.withoutTrivia() ??
            SyntaxFactory.makeTypeIdentifier("Void")
        let returnType: TypeSyntax
        if returnsUnmanaged {
            returnType = Syntax(SyntaxFactory.makeSimpleTypeIdentifier(
                name: SyntaxFactory.makeIdentifier("Unmanaged"),
                genericArgumentClause: SyntaxFactory.makeGenericArgumentClause(
                    leftAngleBracket: SyntaxFactory.makeLeftAngleToken(),
                    arguments: SyntaxFactory.makeGenericArgumentList([
                        SyntaxFactory.makeGenericArgument(argumentType: rawReturnType, trailingComma: nil)
                    ]),
                    rightAngleBracket: SyntaxFactory.makeRightAngleToken()
                )
            )).as(TypeSyntax.self)!
        } else {
            returnType = rawReturnType
        }

        let type = SyntaxFactory.makeFunctionType(
            leftParen: SyntaxFactory.makeLeftParenToken(),
            arguments: arguments,
            rightParen: SyntaxFactory.makeRightParenToken().withTrailingTrivia(.spaces(1)),
            throwsOrRethrowsKeyword: nil,
            arrow: SyntaxFactory.makeArrowToken().withTrailingTrivia(.spaces(1)),
            returnType: returnType
        )
        return Syntax(type)
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
            location: function.startLocation(converter: converter, afterLeadingTrivia: true)
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
                .first(where: { $0.attributeName.text == "objc" })
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
            .first { $0.attributeName.text == "available" }?
            .argument).flatMap { $0.as(AvailabilitySpecListSyntax.self) }
    }

    private func handle(classHook node: ClassDeclSyntax, target: Syntax) {
        let methods = node.members.members
            .compactMap { $0.decl.as(FunctionDeclSyntax.self) }
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
                    diagnosticEngine.diagnose(
                        .staticClassMethodDecl(),
                        location: decl.startLocation(converter: converter)
                    ) { builder in
                        builder.fixItReplace(
                            staticModifier.sourceRange(converter: self.converter, afterLeadingTrivia: true, afterTrailingTrivia: true),
                            with: "\(SyntaxFactory.makeClassKeyword())"
                        )
                    }
                    didFail = true
                    return false
                }
                if decl.modifiers?.contains(where: { ModifierKind($0) == .final }) == true {
                    diagnosticEngine.diagnose(
                        .finalClassMethodDecl(),
                        location: decl.startLocation(converter: converter)
                    )
                    didFail = true
                    return false
                }
                return true
            }
            .compactMap { function -> OrionData.ClassHook.Method? in
                let classModifier = self.classModifier(in: function)
                let isClass = classModifier != nil
                let isDeinit = functionIsDeinitializer(function)
                if isDeinit, let classModifier = classModifier {
                    diagnosticEngine.diagnose(
                        .classDeinit(),
                        location: function.startLocation(converter: converter)
                    ) { builder in
                        builder.fixItRemove(classModifier.sourceRange(converter: self.converter))
                    }
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
            availability: availability(for: node),
            converter: converter
        ))
    }

    private func handle(functionHook node: ClassDeclSyntax) {
        guard let function = node.members.members
            .compactMap({ $0.decl.as(FunctionDeclSyntax.self) })
            .first(where: { $0.identifier.text == "function" })
            else {
                diagnosticEngine.diagnose(
                    .functionHookWithoutFunction(),
                    location: node.startLocation(converter: converter)
                )
                didFail = true
                return
            }

        if let invalidModifiers = function.modifiers?.filter({
            ModifierKind($0)?.isInvalidForFunctionHook == true
        }), !invalidModifiers.isEmpty {
            diagnosticEngine.diagnose(
                .invalidFunctionHookModifiers(),
                location: invalidModifiers[0].startLocation(converter: converter)
            )
            didFail = true
            return
        }

        guard let orionFn = orionFunction(for: function) else { return }
        data.functionHooks.append(OrionData.FunctionHook(
            name: node.identifier.text,
            function: orionFn,
            availability: availability(for: node),
            converter: converter
        ))
    }

    private func handle(tweak identifier: TokenSyntax, hasBackend: Bool) {
        data.tweaks.append(OrionData.Tweak(name: Syntax(identifier), hasBackend: hasBackend, converter: converter))
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
                diagnosticEngine.diagnose(
                    .invalidDeclAccess(declKind: "\(kind)"),
                    location: uninheritable[0].startLocation(converter: converter)
                ) { builder in
                    uninheritable.forEach {
                        builder.fixItRemove($0.sourceRange(converter: self.converter))
                    }
                }
                didFail = true
                return nil
            }
            return kind
        default:
            diagnosticEngine.diagnose(.multipleDecls(), location: node.startLocation(converter: converter))
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
        data.imports.append(node.withoutTrivia())
    }

    override func visitPost(_ node: TokenSyntax) {
        // validates syntax of all directives and registers them
        // for "unused directive" warnings as well
        _ = makeDirectives(for: Syntax(node), warnOnFailure: true)
    }
}
