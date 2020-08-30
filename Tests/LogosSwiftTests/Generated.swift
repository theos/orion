import LogosSwift
import Foundation
import LogosSwift
import Foundation

private final class Logos_ConcreteClassHook_MyHook: MyHook, ConcreteClassHook {
    static let callState = CallState<ClassRequest>()
    let callState = CallState<ClassRequest>()

    private typealias Logos_Function1 = @convention(c) (Target, Selector, Date) -> String
    private static var logos_orig1: Logos_Function1 = { target, _cmd, arg1 in
        Logos_ConcreteClassHook_MyHook(target: target).string(fromDate:)(arg1)
    }
    private static let logos_sel1 = #selector(string(fromDate:))
    @objc override func string(fromDate arg1: Date) -> String {
        switch callState.fetchRequest() {
        case nil:
            return super.string(fromDate:)(arg1)
        case .origCall:
            return Self.logos_orig1(target, Self.logos_sel1, arg1)
        case .superCall:
            return callSuper(Logos_Function1.self) { $0($1, Self.logos_sel1, arg1) }
        }
    }

    private typealias Logos_Function2 = @convention(c) (AnyClass, Selector, Date, DateFormatter.Style, DateFormatter.Style) -> String
    private static var logos_orig2: Logos_Function2 = { target, _cmd, arg1, arg2, arg3 in
        Logos_ConcreteClassHook_MyHook.localizedString(from:dateStyle:timeStyle:)(arg1, arg2, arg3)
    }
    private static let logos_sel2 = #selector(localizedString(from:dateStyle:timeStyle:))
    @objc(localizedStringFromDate:dateStyle:timeStyle:)
        class override func localizedString(
            from arg1: Date, dateStyle arg2: DateFormatter.Style, timeStyle arg3: DateFormatter.Style
        ) -> String {
        switch callState.fetchRequest() {
        case nil:
            return super.localizedString(from:dateStyle:timeStyle:)(arg1, arg2, arg3)
        case .origCall:
            return Self.logos_orig2(target, Self.logos_sel2, arg1, arg2, arg3)
        case .superCall:
            return callSuper(Logos_Function2.self) { $0($1, Self.logos_sel2, arg1, arg2, arg3) }
        }
    }

    static func activate(withBackend backend: Backend) {
        register(backend, logos_sel1, &logos_orig1, isClassMethod: false)
        register(backend, logos_sel2, &logos_orig2, isClassMethod: true)
    }
}

private final class Logos_ConcreteFunctionHook_MyFunctionHook: MyFunctionHook, ConcreteFunctionHook {
    let callState = CallState<FunctionRequest>()

    static var origFunction: @convention(c) (Int32, Int32) -> Int32 = { arg1, arg2 in
        Logos_ConcreteFunctionHook_MyFunctionHook().function(foo:bar:)(arg1, arg2)
    }

    override func function(foo arg1: Int32, bar arg2: Int32) -> Int32 {
        switch callState.fetchRequest() {
        case nil:
            return super.function(foo:bar:)(arg1, arg2)
        case .origCall:
            return Self.origFunction(arg1, arg2)
        }
    }
}

private struct Logos_Tweak: Tweak {}



@_cdecl("__logos_swift_constructor")
func __logos_swift_constructor() {
    Logos_Tweak().activate(
        backend: InternalBackend(),
        hooks: [
            Logos_ConcreteClassHook_MyHook.self,
            Logos_ConcreteFunctionHook_MyFunctionHook.self
        ]
    )
}
