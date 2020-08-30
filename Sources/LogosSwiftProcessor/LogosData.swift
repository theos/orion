import Foundation
import SwiftSyntax

public struct LogosData {
    struct Function {
        let numberOfArguments: Int
        // with args replaced with arg1, arg2, etc
        let function: Syntax // func foo(bar arg1: Blah) -> Blah { /* ... */ }
        let identifier: Syntax // foo(bar:)
        let closure: Syntax // @convention(c) (Blah) -> Blah
    }

    struct ClassHook {
        struct Method {
            let isClassMethod: Bool
            let hasObjcAttribute: Bool
            let function: Function
        }

        var name: String
        var methods: [Method]
    }

    struct FunctionHook {
        var name: String
        var function: Function
    }

    struct Tweak {
        // Syntax so that we have the source location
        var name: Syntax
        var hasBackend: Bool
    }

    var classHooks: [ClassHook] = []
    var functionHooks: [FunctionHook] = []
    var tweaks: [Tweak] = []
    var imports: [ImportDeclSyntax] = []
}

extension LogosData {

    public init(merging data: [LogosData]) {
        classHooks = data.flatMap { $0.classHooks }
        functionHooks = data.flatMap { $0.functionHooks }
        tweaks = data.flatMap { $0.tweaks }
        imports = data.flatMap { $0.imports }
    }

}
