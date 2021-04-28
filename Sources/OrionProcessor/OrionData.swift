import Foundation
import SwiftSyntax

public struct OrionData {
    struct Function {
        var numberOfArguments: Int
        // with args replaced with arg1, arg2, etc
        var function: Syntax // func foo(bar arg1: Blah) -> Blah
        var identifier: Syntax // foo(bar:)
        var closure: Syntax // (Blah) -> Blah
        var directives: [OrionDirective]
        var location: SourceLocation

        var firstPart: String {
            let text = identifier.as(IdentifierExprSyntax.self)!.identifier.text
            if text.hasPrefix("`") && text.hasSuffix("`") {
                return String(text.dropFirst().dropLast())
            }
            return text
        }

        fileprivate func fetchDirective<T: OrionDirective>(ofType type: T.Type) -> T? {
            guard let dir = directives.compactMap({ $0 as? T }).last else { return nil }
            dir.setUsed()
            return dir
        }
    }

    struct ClassHook {
        struct Method {
            enum ObjCAttribute {
                case simple // @objc
                case named(ObjCSelectorSyntax) // @objc(name)
            }

            var isClassMethod: Bool
            var objcAttribute: ObjCAttribute?
            var isDeinitializer: Bool
            var function: Function
            var methodClosure: Syntax // (<Target|AnyClass>, Selector, Blah) -> Blah
            var methodClosureUnmanaged: Syntax // (<Target|AnyClass>, Selector, Blah) -> Unmanaged<Blah>
            var superClosure: Syntax // (UnsafeRawPointer, Selector, Blah) -> Blah
            var superClosureUnmanaged: Syntax // (UnsafeRawPointer, Selector, Blah) -> Unmanaged<Blah>

            func isSuprTramp() -> Bool {
                function.fetchDirective(ofType: OrionDirectives.SuprTramp.self) != nil
            }

            func isAddition() -> Bool {
                function.fetchDirective(ofType: OrionDirectives.New.self) != nil
            }

            func returnsRetained() -> Bool {
                // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/Articles/mmRules.html
                // explains when a method should return a retained value based on the selector. Swift computes
                // method selectors here:
                // https://github.com/apple/swift/blob/06a8902758ca22acc27a28b6cdb68dca3b11203e/lib/AST/Decl.cpp#L6952
                // tl;dr since we're just concerned with the prefix we merely need to check the first part of
                // the method identifier (Swift could add a With/And but that's not relevant to any of our
                // prefixes, and additional selector parts have a colon before them.)

                if let directive = function.fetchDirective(ofType: OrionDirectives.ReturnsRetained.self) {
                    return directive.mode == .retained
                }

                let firstPart: Substring
                if case let .named(name) = objcAttribute, let first = name.first?.name {
                    // respect explicit selector overrides
                    firstPart = first.text[...]
                } else {
                    let text = function.identifier.as(IdentifierExprSyntax.self)!.identifier.text
                    if text.hasPrefix("`") && text.hasSuffix("`") {
                        firstPart = text.dropFirst().dropLast()
                    } else {
                        firstPart = text[...]
                    }
                }

                let root = firstPart.drop /* while: */ { $0 == "_" }

                return root.hasPrefix("alloc")
                    || root.hasPrefix("new")
                    || root.hasPrefix("copy")
                    || root.hasPrefix("mutableCopy")
            }
        }

        var name: String
        var target: Syntax
        var methods: [Method]
        // the ... in @available(...). If there are multiple, only
        // the first one is used; this is technically imperfect but
        // to handle multiple @available's we'd have to understand
        // them semantically to determine their intersection
        var availability: AvailabilitySpecListSyntax?
        var converter: SourceLocationConverter
    }

    struct FunctionHook {
        var name: String
        var function: Function
        var availability: AvailabilitySpecListSyntax?
        var converter: SourceLocationConverter
    }

    struct Tweak {
        // Syntax so that we have the source location
        var name: Syntax
        var hasBackend: Bool
        var converter: SourceLocationConverter
    }

    // we don't provide `[]` as a default value here because that
    // would make it easy to forget to handle the property in
    // init(merging:)
    var classHooks: [ClassHook]
    var functionHooks: [FunctionHook]
    var tweaks: [Tweak]
    var imports: [ImportDeclSyntax]
    var globalDirectives: [OrionDirective]

    public init() {
        classHooks = []
        functionHooks = []
        tweaks = []
        imports = []
        globalDirectives = []
    }

    public init(merging data: [OrionData]) {
        classHooks = data.flatMap { $0.classHooks }
        functionHooks = data.flatMap { $0.functionHooks }
        tweaks = data.flatMap { $0.tweaks }
        imports = data.flatMap { $0.imports }
        globalDirectives = data.flatMap { $0.globalDirectives }
    }

}
