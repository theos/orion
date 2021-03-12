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
    }

    struct ClassHook {
        struct Method {
            var isAddition: Bool // implies the method should be added, not swizzled
            var isClassMethod: Bool
            var hasObjcAttribute: Bool
            var isDeinitializer: Bool
            var function: Function
            var methodClosure: Syntax // (<Target|AnyClass>, Selector, Blah) -> Blah
            var superClosure: Syntax // (UnsafeRawPointer, Selector, Blah) -> Blah
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
