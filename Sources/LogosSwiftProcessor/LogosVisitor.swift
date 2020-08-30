import Foundation
import SwiftSyntax

class LogosVisitor: SyntaxVisitor {
    private static let classHookTypes: Set<String> = ["ClassHook", "NamedClassHook"]
    private static let functionHookTypes: Set<String> = ["FunctionHook"]
    private static let defaultTweakTypes: Set<String> = ["Tweak"]
    private static let backendTweakTypes: Set<String> = ["TweakWithBackend"]

    private(set) var data = LogosData()
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
        case instanceMethod
        case classMethod
    }

    private func makeClosure(for function: FunctionDeclSyntax, kind: FunctionKind) -> Syntax {
        let attribute = SyntaxFactory.makeAttribute(
            atSignToken: SyntaxFactory.makeAtSignToken(),
            attributeName: SyntaxFactory.makeIdentifier("convention"),
            leftParen: SyntaxFactory.makeLeftParenToken(),
            argument: Syntax(SyntaxFactory.makeIdentifier("c")),
            rightParen: SyntaxFactory.makeRightParenToken().withTrailingTrivia(.spaces(1)),
            tokenList: nil
        )
        let attributes = SyntaxFactory.makeAttributeList([Syntax(attribute)])

        let params = function.signature.input.parameterList

        let prefixTypes: [TypeSyntax]
        switch kind {
        case .function:
            prefixTypes = []
        case .instanceMethod:
            prefixTypes = [
                SyntaxFactory.makeTypeIdentifier("Target"),
                SyntaxFactory.makeTypeIdentifier("Selector")
            ]
        case .classMethod:
            prefixTypes = [
                SyntaxFactory.makeTypeIdentifier("AnyClass"),
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
        return Syntax(SyntaxFactory.makeAttributedType(specifier: nil, attributes: attributes, baseType: TypeSyntax(type)))
    }

    private func logosFunction(for function: FunctionDeclSyntax, kind: FunctionKind) -> LogosData.Function {
        LogosData.Function(
            numberOfArguments: function.signature.input.parameterList.count,
            function: makeFunction(for: function),
            identifier: makeIdentifier(for: function),
            closure: makeClosure(for: function, kind: kind)
        )
    }

    private func functionHasClass(_ function: FunctionDeclSyntax) -> Bool {
        function.modifiers?.contains { $0.name.text == "class" } == true
    }

    private func functionHasObjc(_ function: FunctionDeclSyntax) -> Bool {
        function.attributes?.contains { $0.as(AttributeSyntax.self)?.attributeName.text == "objc" } == true
    }

    private func handle(classHook node: ClassDeclSyntax) {
        let methods = node.members.members
            .compactMap { $0.decl.as(FunctionDeclSyntax.self) }
            .filter { (decl: FunctionDeclSyntax) -> Bool in
                guard let modifiers = decl.modifiers else { return true }
                return !modifiers.contains { $0.name.text == "private" || $0.name.text == "fileprivate" }
            }
            .map { function -> LogosData.ClassHook.Method in
                let isClass = functionHasClass(function)
                return LogosData.ClassHook.Method(
                    isClassMethod: isClass,
                    hasObjcAttribute: functionHasObjc(function),
                    function: logosFunction(for: function, kind: isClass ? .classMethod : .instanceMethod)
                )
            }
        data.classHooks.append(LogosData.ClassHook(name: node.identifier.text, methods: methods))
    }

    private func handle(functionHook node: ClassDeclSyntax) {
        guard let function = node.members.members
            .compactMap({ $0.decl.as(FunctionDeclSyntax.self) })
            .first(where: { $0.identifier.text == "function" })
            else { return }
        data.functionHooks.append(LogosData.FunctionHook(
            name: node.identifier.text,
            function: logosFunction(for: function, kind: .function)
        ))
    }

    private func handle(tweak identifier: TokenSyntax, hasBackend: Bool) {
        data.tweaks.append(LogosData.Tweak(name: Syntax(identifier), hasBackend: hasBackend))
    }

    private enum DeclarationKind {
        case classHook
        case functionHook
        case tweak(hasBackend: Bool)
    }

    private func declarationKind(for node: TypeInheritanceClauseSyntax?) -> DeclarationKind? {
        guard let node = node else { return nil }
        let idents = node.inheritedTypeCollection.compactMap {
            $0.typeName.as(SimpleTypeIdentifierSyntax.self)?.name.text
        }
        var declarationKinds: [DeclarationKind] = []
        if idents.contains(where: Self.classHookTypes.contains) { declarationKinds.append(.classHook) }
        if idents.contains(where: Self.functionHookTypes.contains) { declarationKinds.append(.functionHook) }
        if idents.contains(where: Self.defaultTweakTypes.contains) { declarationKinds.append(.tweak(hasBackend: false)) }
        if idents.contains(where: Self.backendTweakTypes.contains) { declarationKinds.append(.tweak(hasBackend: true)) }
        switch declarationKinds.count {
        case 0: return nil
        case 1: return declarationKinds[0]
        default:
            // TODO: Emit error saying you can't be multiple declarations
            didFail = true
            return nil
        }
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        switch declarationKind(for: node.inheritanceClause) {
        case .tweak(let hasBackend):
            handle(tweak: node.identifier, hasBackend: hasBackend)
        case .classHook, .functionHook, nil:
            break
        }
    }

    override func visitPost(_ node: StructDeclSyntax) {
        switch declarationKind(for: node.inheritanceClause) {
        case .tweak(let hasBackend):
            handle(tweak: node.identifier, hasBackend: hasBackend)
        case .classHook, .functionHook, nil:
            break
        }
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        switch declarationKind(for: node.inheritanceClause) {
        case .tweak(let hasBackend):
            handle(tweak: node.identifier, hasBackend: hasBackend)
        case .classHook:
            handle(classHook: node)
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
