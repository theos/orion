import Foundation
import SwiftSyntax

public struct OrionData {
    struct Directive {
        static let prefix = "orion:"

        let name: String
        let arguments: [String]

        init?(text: String) {
            guard text.hasPrefix(Self.prefix) else { return nil }
            let dropped = text.dropFirst(Self.prefix.count)
            let parts = dropped.split(separator: " ")
            guard let name = parts.first else { return nil }
            self.name = String(name)
            self.arguments = parts.dropFirst().map(String.init)
        }
    }

    struct Function {
        var numberOfArguments: Int
        // with args replaced with arg1, arg2, etc
        var function: Syntax // func foo(bar arg1: Blah) -> Blah
        var identifier: Syntax // foo(bar:)
        var closure: Syntax // (Blah) -> Blah
        var directives: [Directive]

        var firstPart: String {
            let text = identifier.as(IdentifierExprSyntax.self)!.identifier.text
            if text.hasPrefix("`") && text.hasSuffix("`") {
                return String(text.dropFirst().dropLast())
            }
            return text
        }
    }

    struct ClassHook {
        struct Method {
            enum ObjCAttribute {
                case simple // @objc
                case named(ObjCSelectorSyntax) // @objc(name)
            }

            var isAddition: Bool // implies the method should be added, not swizzled
            var isClassMethod: Bool
            var objcAttribute: ObjCAttribute?
            var isDeinitializer: Bool
            var function: Function
            var methodClosure: Syntax // (<Target|AnyClass>, Selector, Blah) -> Blah
            var methodClosureUnmanaged: Syntax // (<Target|AnyClass>, Selector, Blah) -> Unmanaged<Blah>
            var superClosure: Syntax // (UnsafeRawPointer, Selector, Blah) -> Blah
            var superClosureUnmanaged: Syntax // (UnsafeRawPointer, Selector, Blah) -> Unmanaged<Blah>

            var returnsRetained: Bool {
                // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/Articles/mmRules.html
                // explains when a method should return a retained value based on the selector. Swift computes
                // method selectors here:
                // https://github.com/apple/swift/blob/06a8902758ca22acc27a28b6cdb68dca3b11203e/lib/AST/Decl.cpp#L6952
                // tl;dr since we're just concerned with the prefix we merely need to check the first part of
                // the method identifier (Swift could add a With/And but that's not relevant to any of our
                // prefixes, and additional selector parts have a colon before them.)

                // TODO: allow user to override this property with a comment, similar to
                // NS_RETURNS_[NOT_]RETAINED

                if let directive = function.directives.last(where: { $0.name == "arc" }),
                   let arg = directive.arguments.first {
                    if arg == "retained" {
                        return true
                    } else if arg == "not_retained" {
                        return false
                    }
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
        var converter: SourceLocationConverter
    }

    struct FunctionHook {
        var name: String
        var function: Function
        var converter: SourceLocationConverter
    }

    struct Tweak {
        // Syntax so that we have the source location
        var name: Syntax
        var hasBackend: Bool
        var converter: SourceLocationConverter
    }

    var classHooks: [ClassHook] = []
    var functionHooks: [FunctionHook] = []
    var tweaks: [Tweak] = []
    var imports: [ImportDeclSyntax] = []
}

extension OrionData {

    public init(merging data: [OrionData]) {
        classHooks = data.flatMap { $0.classHooks }
        functionHooks = data.flatMap { $0.functionHooks }
        tweaks = data.flatMap { $0.tweaks }
        imports = data.flatMap { $0.imports }
    }

}
