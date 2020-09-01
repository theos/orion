import Orion
import Foundation
import Orion
import Foundation

private final class Orion_ClassHook1: MyHook, ConcreteClassHook {
    static let callState = CallState<ClassRequest>()
    let callState = CallState<ClassRequest>()

    private static var orion_orig1: @convention(c) (Target, Selector, Date) -> String = { target, _cmd, arg1 in
        Orion_ClassHook1(target: target).string(fromDate:)(arg1)
    }
    private static let orion_sel1 = #selector(string(fromDate:) as (Self) -> (Date) -> String)
    @objc override func string(fromDate arg1: Date) -> String {
        switch callState.fetchRequest() {
        case nil, .selfCall:
            return super.string(fromDate:)(arg1)
        case .origCall:
            return Self.orion_orig1(target, Self.orion_sel1, arg1)
        case .superCall:
            return callSuper((@convention(c) (UnsafeRawPointer, Selector, Date) -> String).self) { $0($1, Self.orion_sel1, arg1) }
        }
    }

    private static var orion_orig2: @convention(c) (AnyClass, Selector, Date, DateFormatter.Style, DateFormatter.Style) -> String = { target, _cmd, arg1, arg2, arg3 in
        Orion_ClassHook1.localizedString(from:dateStyle:timeStyle:)(arg1, arg2, arg3)
    }
    private static let orion_sel2 = #selector(localizedString(from:dateStyle:timeStyle:) as (Date, DateFormatter.Style, DateFormatter.Style) -> String)
    @objc(localizedStringFromDate:dateStyle:timeStyle:)
        class override func localizedString(
            from arg1: Date, dateStyle arg2: DateFormatter.Style, timeStyle arg3: DateFormatter.Style
        ) -> String {
        switch callState.fetchRequest() {
        case nil, .selfCall:
            return super.localizedString(from:dateStyle:timeStyle:)(arg1, arg2, arg3)
        case .origCall:
            return Self.orion_orig2(target, Self.orion_sel2, arg1, arg2, arg3)
        case .superCall:
            return callSuper((@convention(c) (UnsafeRawPointer, Selector, Date, DateFormatter.Style, DateFormatter.Style) -> String).self) { $0($1, Self.orion_sel2, arg1, arg2, arg3) }
        }
    }

    static func activate(withBackend backend: Backend) {
        register(backend, orion_sel1, &orion_orig1, isClassMethod: false)
        register(backend, orion_sel2, &orion_orig2, isClassMethod: true)
    }
}

private final class Orion_ClassHook2: SuperHook, ConcreteClassHook {
    static let callState = CallState<ClassRequest>()
    let callState = CallState<ClassRequest>()

    private static var orion_orig1: @convention(c) (Target, Selector) -> String = { target, _cmd in
        Orion_ClassHook2(target: target).description()
    }
    private static let orion_sel1 = #selector(description as (Self) -> () -> String)
    @objc override func description() -> String {
        switch callState.fetchRequest() {
        case nil, .selfCall:
            return super.description()
        case .origCall:
            return Self.orion_orig1(target, Self.orion_sel1)
        case .superCall:
            return callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel1) }
        }
    }

    private static var orion_orig2: @convention(c) (Target, Selector) -> String = { target, _cmd in
        Orion_ClassHook2(target: target).hooked()
    }
    private static let orion_sel2 = #selector(hooked as (Self) -> () -> String)
    @objc override func hooked() -> String {
        switch callState.fetchRequest() {
        case nil, .selfCall:
            return super.hooked()
        case .origCall:
            return Self.orion_orig2(target, Self.orion_sel2)
        case .superCall:
            return callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel2) }
        }
    }

    static func activate(withBackend backend: Backend) {
        register(backend, orion_sel1, &orion_orig1, isClassMethod: false)
        register(backend, orion_sel2, &orion_orig2, isClassMethod: false)
    }
}

private final class Orion_ClassHook3: PropertyHookX, ConcreteClassHook {
    static let callState = CallState<ClassRequest>()
    let callState = CallState<ClassRequest>()

    private static var orion_orig1: @convention(c) (Target, Selector) -> Int = { target, _cmd in
        Orion_ClassHook3(target: target).getXValue()
    }
    private static let orion_sel1 = #selector(getXValue as (Self) -> () -> Int)
    @objc override func getXValue() -> Int {
        switch callState.fetchRequest() {
        case nil, .selfCall:
            return super.getXValue()
        case .origCall:
            return Self.orion_orig1(target, Self.orion_sel1)
        case .superCall:
            return callSuper((@convention(c) (UnsafeRawPointer, Selector) -> Int).self) { $0($1, Self.orion_sel1) }
        }
    }

    private static var orion_orig2: @convention(c) (Target, Selector, Int) -> Void = { target, _cmd, arg1 in
        Orion_ClassHook3(target: target).setXValue(_:)(arg1)
    }
    private static let orion_sel2 = #selector(setXValue(_:) as (Self) -> (Int) -> Void)
    @objc override func setXValue(_ arg1: Int)  {
        switch callState.fetchRequest() {
        case nil, .selfCall:
            return super.setXValue(_:)(arg1)
        case .origCall:
            return Self.orion_orig2(target, Self.orion_sel2, arg1)
        case .superCall:
            return callSuper((@convention(c) (UnsafeRawPointer, Selector, Int) -> Void).self) { $0($1, Self.orion_sel2, arg1) }
        }
    }

    static func activate(withBackend backend: Backend) {
        register(backend, orion_sel1, &orion_orig1, isClassMethod: false)
        register(backend, orion_sel2, &orion_orig2, isClassMethod: false)
    }
}

private final class Orion_ClassHook4: PropertyHookY, ConcreteClassHook {
    static let callState = CallState<ClassRequest>()
    let callState = CallState<ClassRequest>()

    private static var orion_orig1: @convention(c) (Target, Selector) -> Int = { target, _cmd in
        Orion_ClassHook4(target: target).getYValue()
    }
    private static let orion_sel1 = #selector(getYValue as (Self) -> () -> Int)
    @objc override func getYValue() -> Int {
        switch callState.fetchRequest() {
        case nil, .selfCall:
            return super.getYValue()
        case .origCall:
            return Self.orion_orig1(target, Self.orion_sel1)
        case .superCall:
            return callSuper((@convention(c) (UnsafeRawPointer, Selector) -> Int).self) { $0($1, Self.orion_sel1) }
        }
    }

    private static var orion_orig2: @convention(c) (Target, Selector, Int) -> Void = { target, _cmd, arg1 in
        Orion_ClassHook4(target: target).setYValue(_:)(arg1)
    }
    private static let orion_sel2 = #selector(setYValue(_:) as (Self) -> (Int) -> Void)
    @objc override func setYValue(_ arg1: Int)  {
        switch callState.fetchRequest() {
        case nil, .selfCall:
            return super.setYValue(_:)(arg1)
        case .origCall:
            return Self.orion_orig2(target, Self.orion_sel2, arg1)
        case .superCall:
            return callSuper((@convention(c) (UnsafeRawPointer, Selector, Int) -> Void).self) { $0($1, Self.orion_sel2, arg1) }
        }
    }

    static func activate(withBackend backend: Backend) {
        register(backend, orion_sel1, &orion_orig1, isClassMethod: false)
        register(backend, orion_sel2, &orion_orig2, isClassMethod: false)
    }
}

private final class Orion_ClassHook5: PropertyHook2, ConcreteClassHook {
    static let callState = CallState<ClassRequest>()
    let callState = CallState<ClassRequest>()

    private static var orion_orig1: @convention(c) (Target, Selector) -> Int = { target, _cmd in
        Orion_ClassHook5(target: target).getXValue()
    }
    private static let orion_sel1 = #selector(getXValue as (Self) -> () -> Int)
    @objc override func getXValue() -> Int {
        switch callState.fetchRequest() {
        case nil, .selfCall:
            return super.getXValue()
        case .origCall:
            return Self.orion_orig1(target, Self.orion_sel1)
        case .superCall:
            return callSuper((@convention(c) (UnsafeRawPointer, Selector) -> Int).self) { $0($1, Self.orion_sel1) }
        }
    }

    private static var orion_orig2: @convention(c) (Target, Selector, Int) -> Void = { target, _cmd, arg1 in
        Orion_ClassHook5(target: target).setXValue(_:)(arg1)
    }
    private static let orion_sel2 = #selector(setXValue(_:) as (Self) -> (Int) -> Void)
    @objc override func setXValue(_ arg1: Int)  {
        switch callState.fetchRequest() {
        case nil, .selfCall:
            return super.setXValue(_:)(arg1)
        case .origCall:
            return Self.orion_orig2(target, Self.orion_sel2, arg1)
        case .superCall:
            return callSuper((@convention(c) (UnsafeRawPointer, Selector, Int) -> Void).self) { $0($1, Self.orion_sel2, arg1) }
        }
    }

    static func activate(withBackend backend: Backend) {
        register(backend, orion_sel1, &orion_orig1, isClassMethod: false)
        register(backend, orion_sel2, &orion_orig2, isClassMethod: false)
    }
}

private final class Orion_FunctionHook1: MyFunctionHook, ConcreteFunctionHook {
    let callState = CallState<FunctionRequest>()

    static var origFunction: @convention(c) (Int32, Int32) -> Int32 = { arg1, arg2 in
        Orion_FunctionHook1().function(foo:bar:)(arg1, arg2)
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

@_cdecl("__orion_constructor")
func __orion_constructor() {
    DefaultTweak().activate(
        backend: InternalBackend(),
        hooks: [
            Orion_ClassHook1.self,
            Orion_ClassHook2.self,
            Orion_ClassHook3.self,
            Orion_ClassHook4.self,
            Orion_ClassHook5.self,
            Orion_FunctionHook1.self
        ]
    )
}
