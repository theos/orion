import Foundation
import SwiftSyntax

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
    }

    private enum ModifierKind: String {
        case `private`, `fileprivate`, `final`, `class`, `static`

        static let uninheritable: Set<ModifierKind> = [
            .private, .fileprivate, .final
        ]

        static let ignoredInMethod: Set<ModifierKind> = [
            .private, .fileprivate
        ]

        static let invalidForFunctionHooks: Set<ModifierKind> = [
            .private, .fileprivate, .final, .class, .static
        ]

        init?(_ decl: DeclModifierSyntax) {
            self.init(rawValue: decl.name.text)
        }

        var isUninheritable: Bool { Self.uninheritable.contains(self) }
        var isIgnoredInMethod: Bool { Self.ignoredInMethod.contains(self) }
        var isInvalidForFunctionHook: Bool { Self.invalidForFunctionHooks.contains(self) }
    }

    // don't consider these names as method hooks
    private static let ignoredMethodNames: Set<String> = [
        // these are the optional AnyHook protocol methods; don't treat them as hooks
        "hookWillActivate", "hookDidActivate"
    ]

    let converter: SourceLocationConverter
    let diagnosticEngine: DiagnosticEngine
    init(diagnosticEngine: DiagnosticEngine, sourceLocationConverter: SourceLocationConverter) {
        self.diagnosticEngine = diagnosticEngine
        self.converter = sourceLocationConverter
    }

    private(set) var data = OrionData()
    private(set) var didFail = false

    private func makeFunction(for function: FunctionDeclSyntax) -> Syntax {
        let elements = function.signature.input.parameterList.enumerated().map { idx, element -> FunctionParameterSyntax in
            var element = element
            // TODO: Fix force unwrapping
            if element.firstName!.trailingTrivia.isEmpty {
                element = element.withFirstName(element.firstName?.withTrailingTrivia(.spaces(1)))
            }
            return element.withSecondName(SyntaxFactory.makeIdentifier("arg\(idx + 1)"))
        }
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

    private func makeIdentifier(for function: FunctionDeclSyntax) -> Syntax {
        let declNameArguments: DeclNameArgumentsSyntax?

        let params = function.signature.input.parameterList
        if params.isEmpty {
            declNameArguments = nil
        } else {
            let argumentsArray = function.signature.input.parameterList.map {
                // TODO: Fix force unwrapping
                SyntaxFactory.makeDeclNameArgument(name: $0.firstName!.withoutTrivia(), colon: $0.colon!.withoutTrivia())
            }
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
        case method(firstType: String)
    }

    private func makeClosure(for function: FunctionDeclSyntax, kind: FunctionKind) -> Syntax {
        let params = function.signature.input.parameterList

        let prefixTypes: [TypeSyntax]
        switch kind {
        case .function:
            prefixTypes = []
        case .method(let firstType):
            prefixTypes = [
                SyntaxFactory.makeTypeIdentifier(firstType),
                SyntaxFactory.makeTypeIdentifier("Selector")
            ]
        }
        // TODO: Fix force unwrapping
        let types = prefixTypes + params.map { $0.type! }

        let last = types.last
        let argumentsArray = types.map { type in
            SyntaxFactory.makeTupleTypeElement(
                type: type,
                trailingComma: type == last ? nil : SyntaxFactory.makeCommaToken().withTrailingTrivia(.spaces(1))
            )
        }
        let arguments = SyntaxFactory.makeTupleTypeElementList(argumentsArray)
        let returnType = function.signature.output?.returnType.withoutTrivia() ?? SyntaxFactory.makeTypeIdentifier("Void")

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

    private func orionFunction(for function: FunctionDeclSyntax) -> OrionData.Function {
        OrionData.Function(
            numberOfArguments: function.signature.input.parameterList.count,
            function: makeFunction(for: function),
            identifier: makeIdentifier(for: function),
            closure: makeClosure(for: function, kind: .function)
        )
    }

    private func staticModifier(in function: FunctionDeclSyntax) -> DeclModifierSyntax? {
        function.modifiers?.first { ModifierKind($0) == .static }
    }

    // TODO: Maybe use a comment above the function instead? Something
    // like `// orion:set:next addition` (similar to swiftlint)
    private func functionIsAddition(_ function: FunctionDeclSyntax) -> Bool {
        function.modifiers?.contains { ModifierKind($0) == .final } == true
    }

    private func functionHasClass(_ function: FunctionDeclSyntax) -> Bool {
        function.modifiers?.contains { ModifierKind($0) == .class } == true
    }

    private func functionHasObjc(_ function: FunctionDeclSyntax) -> Bool {
        function.attributes?.contains { $0.as(AttributeSyntax.self)?.attributeName.text == "objc" } == true
    }

    private func handle(classHook node: ClassDeclSyntax, target: Syntax) {
        let methods = node.members.members
            .compactMap { $0.decl.as(FunctionDeclSyntax.self) }
            .filter { (decl: FunctionDeclSyntax) -> Bool in
                guard let modifiers = decl.modifiers else { return true }
                // This allows users to use one of these declarations to add a helper function,
                // which isn't actually a hook, to a hook type
                return !modifiers.contains { ModifierKind($0)?.isIgnoredInMethod == true }
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
                return true
            }
            .map { function -> OrionData.ClassHook.Method in
                let isClass = functionHasClass(function)
                return OrionData.ClassHook.Method(
                    isAddition: functionIsAddition(function),
                    isClassMethod: isClass,
                    hasObjcAttribute: functionHasObjc(function),
                    function: orionFunction(for: function),
                    methodClosure: makeClosure(for: function, kind: .method(firstType: isClass ? "AnyClass" : "Target")),
                    superClosure: makeClosure(for: function, kind: .method(firstType: "UnsafeRawPointer"))
                )
            }
        data.classHooks.append(OrionData.ClassHook(
            name: node.identifier.text,
            target: target,
            methods: methods,
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

        data.functionHooks.append(OrionData.FunctionHook(
            name: node.identifier.text,
            function: orionFunction(for: function),
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
            let uninheritable = modifiers?.filter { ModifierKind($0)?.isUninheritable == true } ?? []
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

    override func visitPost(_ node: ImportDeclSyntax) {
        data.imports.append(node.withoutTrivia())
    }
}
