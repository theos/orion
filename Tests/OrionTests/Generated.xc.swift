import Foundation
import Orion
import OrionTestSupport

private class Orion_ClassHook1: BasicHook, ConcreteClassHook {
    final class OrigType: Orion_ClassHook1 {
        @objc override func someTestMethod() -> String {
            Self.orion_orig1(target, Self.orion_sel1)
        }

        @objc override func someTestMethod(withArgument arg1: Int32) -> String {
            Self.orion_orig2(target, Self.orion_sel2, arg1)
        }

        @objc class override func someTestMethod2(withArgument arg1: Int32) -> String {
            Self.orion_orig3(target, Self.orion_sel3, arg1)
        }
    }

    final class SuprType: Orion_ClassHook1 {
        @objc override func someTestMethod() -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel1) }
        }

        @objc override func someTestMethod(withArgument arg1: Int32) -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector, Int32) -> String).self) { $0($1, Self.orion_sel2, arg1) }
        }

        @objc class override func someTestMethod2(withArgument arg1: Int32) -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector, Int32) -> String).self) { $0($1, Self.orion_sel3, arg1) }
        }
    }

    private static let orion_sel1 = #selector(someTestMethod as (Self) -> () -> String)
    private static var orion_orig1: @convention(c) (Target, Selector) -> String = { target, _cmd in
        Orion_ClassHook1(target: target).someTestMethod()
    }

    private static let orion_sel2 = #selector(someTestMethod(withArgument:) as (Self) -> (Int32) -> String)
    private static var orion_orig2: @convention(c) (Target, Selector, Int32) -> String = { target, _cmd, arg1 in
        Orion_ClassHook1(target: target).someTestMethod(withArgument:)(arg1)
    }

    private static let orion_sel3 = #selector(someTestMethod2(withArgument:) as (Int32) -> String)
    private static var orion_orig3: @convention(c) (AnyClass, Selector, Int32) -> String = { target, _cmd, arg1 in
        Orion_ClassHook1.someTestMethod2(withArgument:)(arg1)
    }

    static func activate<Builder: HookBuilder>(withClassHookBuilder builder: inout ClassHookBuilder<Builder>) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        builder.addHook(orion_sel2, orion_orig2, isClassMethod: false) { orion_orig2 = $0 }
        builder.addHook(orion_sel3, orion_orig3, isClassMethod: true) { orion_orig3 = $0 }
    }
}

private class Orion_ClassHook2: NamedBasicHook, ConcreteClassHook {
    final class OrigType: Orion_ClassHook2 {
        @objc override func methodForNamedTest() -> Bool {
            Self.orion_orig1(target, Self.orion_sel1)
        }

        @objc class override func classMethodForNamedTest(withArgument arg1: String) -> [String] {
            Self.orion_orig2(target, Self.orion_sel2, arg1)
        }
    }

    final class SuprType: Orion_ClassHook2 {
        @objc override func methodForNamedTest() -> Bool {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> Bool).self) { $0($1, Self.orion_sel1) }
        }

        @objc class override func classMethodForNamedTest(withArgument arg1: String) -> [String] {
            callSuper((@convention(c) (UnsafeRawPointer, Selector, String) -> [String]).self) { $0($1, Self.orion_sel2, arg1) }
        }
    }

    private static let orion_sel1 = #selector(methodForNamedTest as (Self) -> () -> Bool)
    private static var orion_orig1: @convention(c) (Target, Selector) -> Bool = { target, _cmd in
        Orion_ClassHook2(target: target).methodForNamedTest()
    }

    private static let orion_sel2 = #selector(classMethodForNamedTest(withArgument:) as (String) -> [String])
    private static var orion_orig2: @convention(c) (AnyClass, Selector, String) -> [String] = { target, _cmd, arg1 in
        Orion_ClassHook2.classMethodForNamedTest(withArgument:)(arg1)
    }

    static func activate<Builder: HookBuilder>(withClassHookBuilder builder: inout ClassHookBuilder<Builder>) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        builder.addHook(orion_sel2, orion_orig2, isClassMethod: true) { orion_orig2 = $0 }
    }
}

private class Orion_ClassHook3: InheritedHook, ConcreteClassHook {
    final class OrigType: Orion_ClassHook3 {
        @objc class override func someTestMethod3() -> String {
            Self.orion_orig1(target, Self.orion_sel1)
        }
    }

    final class SuprType: Orion_ClassHook3 {
        @objc class override func someTestMethod3() -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel1) }
        }
    }

    private static let orion_sel1 = #selector(someTestMethod3 as () -> String)
    private static var orion_orig1: @convention(c) (AnyClass, Selector) -> String = { target, _cmd in
        Orion_ClassHook3.someTestMethod3()
    }

    static func activate<Builder: HookBuilder>(withClassHookBuilder builder: inout ClassHookBuilder<Builder>) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: true) { orion_orig1 = $0 }
    }
}

private class Orion_ClassHook4: InitHook, ConcreteClassHook {
    final class OrigType: Orion_ClassHook4 {
        @objc override func `init`() -> Target {
            Self.orion_orig1(target, Self.orion_sel1)
        }

        @objc override func `init`(withX arg1: Int32) -> Target {
            Self.orion_orig2(target, Self.orion_sel2, arg1)
        }
    }

    final class SuprType: Orion_ClassHook4 {
        @objc override func `init`() -> Target {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> Target).self) { $0($1, Self.orion_sel1) }
        }

        @objc override func `init`(withX arg1: Int32) -> Target {
            callSuper((@convention(c) (UnsafeRawPointer, Selector, Int32) -> Target).self) { $0($1, Self.orion_sel2, arg1) }
        }
    }

    private static let orion_sel1 = #selector(`init` as (Self) -> () -> Target)
    private static var orion_orig1: @convention(c) (Target, Selector) -> Target = { target, _cmd in
        Orion_ClassHook4(target: target).`init`()
    }

    private static let orion_sel2 = #selector(`init`(withX:) as (Self) -> (Int32) -> Target)
    private static var orion_orig2: @convention(c) (Target, Selector, Int32) -> Target = { target, _cmd, arg1 in
        Orion_ClassHook4(target: target).`init`(withX:)(arg1)
    }

    static func activate<Builder: HookBuilder>(withClassHookBuilder builder: inout ClassHookBuilder<Builder>) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        builder.addHook(orion_sel2, orion_orig2, isClassMethod: false) { orion_orig2 = $0 }
    }
}

private class Orion_ClassHook5: SuperHook, ConcreteClassHook {
    final class OrigType: Orion_ClassHook5 {
        @objc override func description() -> String {
            Self.orion_orig1(target, Self.orion_sel1)
        }

        @objc override func hooked() -> String {
            Self.orion_orig2(target, Self.orion_sel2)
        }
    }

    final class SuprType: Orion_ClassHook5 {
        @objc override func description() -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel1) }
        }

        @objc override func hooked() -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel2) }
        }
    }

    private static let orion_sel1 = #selector(description as (Self) -> () -> String)
    private static var orion_orig1: @convention(c) (Target, Selector) -> String = { target, _cmd in
        Orion_ClassHook5(target: target).description()
    }

    private static let orion_sel2 = #selector(hooked as (Self) -> () -> String)
    private static var orion_orig2: @convention(c) (Target, Selector) -> String = { target, _cmd in
        Orion_ClassHook5(target: target).hooked()
    }

    static func activate<Builder: HookBuilder>(withClassHookBuilder builder: inout ClassHookBuilder<Builder>) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        builder.addHook(orion_sel2, orion_orig2, isClassMethod: false) { orion_orig2 = $0 }
    }
}

private class Orion_ClassHook6: PropertyHookX, ConcreteClassHook {
    final class OrigType: Orion_ClassHook6 {
        @objc override func getXValue() -> Int {
            Self.orion_orig1(target, Self.orion_sel1)
        }

        @objc override func setXValue(_ arg1: Int)  {
            Self.orion_orig2(target, Self.orion_sel2, arg1)
        }
    }

    final class SuprType: Orion_ClassHook6 {
        @objc override func getXValue() -> Int {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> Int).self) { $0($1, Self.orion_sel1) }
        }

        @objc override func setXValue(_ arg1: Int)  {
            callSuper((@convention(c) (UnsafeRawPointer, Selector, Int) -> Void).self) { $0($1, Self.orion_sel2, arg1) }
        }
    }

    private static let orion_sel1 = #selector(getXValue as (Self) -> () -> Int)
    private static var orion_orig1: @convention(c) (Target, Selector) -> Int = { target, _cmd in
        Orion_ClassHook6(target: target).getXValue()
    }

    private static let orion_sel2 = #selector(setXValue(_:) as (Self) -> (Int) -> Void)
    private static var orion_orig2: @convention(c) (Target, Selector, Int) -> Void = { target, _cmd, arg1 in
        Orion_ClassHook6(target: target).setXValue(_:)(arg1)
    }

    static func activate<Builder: HookBuilder>(withClassHookBuilder builder: inout ClassHookBuilder<Builder>) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        builder.addHook(orion_sel2, orion_orig2, isClassMethod: false) { orion_orig2 = $0 }
    }
}

private class Orion_ClassHook7: PropertyHookY, ConcreteClassHook {
    final class OrigType: Orion_ClassHook7 {
        @objc override func getYValue() -> Int {
            Self.orion_orig1(target, Self.orion_sel1)
        }

        @objc override func setYValue(_ arg1: Int)  {
            Self.orion_orig2(target, Self.orion_sel2, arg1)
        }
    }

    final class SuprType: Orion_ClassHook7 {
        @objc override func getYValue() -> Int {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> Int).self) { $0($1, Self.orion_sel1) }
        }

        @objc override func setYValue(_ arg1: Int)  {
            callSuper((@convention(c) (UnsafeRawPointer, Selector, Int) -> Void).self) { $0($1, Self.orion_sel2, arg1) }
        }
    }

    private static let orion_sel1 = #selector(getYValue as (Self) -> () -> Int)
    private static var orion_orig1: @convention(c) (Target, Selector) -> Int = { target, _cmd in
        Orion_ClassHook7(target: target).getYValue()
    }

    private static let orion_sel2 = #selector(setYValue(_:) as (Self) -> (Int) -> Void)
    private static var orion_orig2: @convention(c) (Target, Selector, Int) -> Void = { target, _cmd, arg1 in
        Orion_ClassHook7(target: target).setYValue(_:)(arg1)
    }

    static func activate<Builder: HookBuilder>(withClassHookBuilder builder: inout ClassHookBuilder<Builder>) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        builder.addHook(orion_sel2, orion_orig2, isClassMethod: false) { orion_orig2 = $0 }
    }
}

private class Orion_ClassHook8: PropertyHook2, ConcreteClassHook {
    final class OrigType: Orion_ClassHook8 {
        @objc override func getXValue() -> Int {
            Self.orion_orig1(target, Self.orion_sel1)
        }

        @objc override func setXValue(_ arg1: Int)  {
            Self.orion_orig2(target, Self.orion_sel2, arg1)
        }
    }

    final class SuprType: Orion_ClassHook8 {
        @objc override func getXValue() -> Int {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> Int).self) { $0($1, Self.orion_sel1) }
        }

        @objc override func setXValue(_ arg1: Int)  {
            callSuper((@convention(c) (UnsafeRawPointer, Selector, Int) -> Void).self) { $0($1, Self.orion_sel2, arg1) }
        }
    }

    private static let orion_sel1 = #selector(getXValue as (Self) -> () -> Int)
    private static var orion_orig1: @convention(c) (Target, Selector) -> Int = { target, _cmd in
        Orion_ClassHook8(target: target).getXValue()
    }

    private static let orion_sel2 = #selector(setXValue(_:) as (Self) -> (Int) -> Void)
    private static var orion_orig2: @convention(c) (Target, Selector, Int) -> Void = { target, _cmd, arg1 in
        Orion_ClassHook8(target: target).setXValue(_:)(arg1)
    }

    static func activate<Builder: HookBuilder>(withClassHookBuilder builder: inout ClassHookBuilder<Builder>) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        builder.addHook(orion_sel2, orion_orig2, isClassMethod: false) { orion_orig2 = $0 }
    }
}

private class Orion_FunctionHook1: AtoiHook, ConcreteFunctionHook {
    static let orion_shared = Orion_FunctionHook1()

    static var origFunction: @convention(c) (UnsafePointer<Int8>) -> Int32 = { arg1 in
        Orion_FunctionHook1.orion_shared.function(_:)(arg1)
    }

    final class OrigType: Orion_FunctionHook1 {
        override func function(_ arg1: UnsafePointer<Int8>) -> Int32 {
            Self.origFunction(arg1)
        }
    }
}

private class Orion_FunctionHook2: AtofHook, ConcreteFunctionHook {
    static let orion_shared = Orion_FunctionHook2()

    static var origFunction: @convention(c) (UnsafePointer<Int8>) -> Double = { arg1 in
        Orion_FunctionHook2.orion_shared.function(_:)(arg1)
    }

    final class OrigType: Orion_FunctionHook2 {
        override func function(_ arg1: UnsafePointer<Int8>) -> Double {
            Self.origFunction(arg1)
        }
    }
}

@_cdecl("__orion_constructor")
func __orion_constructor() {
    HooksTweak().activate(
        hooks: [
            Orion_ClassHook1.self,
            Orion_ClassHook2.self,
            Orion_ClassHook3.self,
            Orion_ClassHook4.self,
            Orion_ClassHook5.self,
            Orion_ClassHook6.self,
            Orion_ClassHook7.self,
            Orion_ClassHook8.self,
            Orion_FunctionHook1.self,
            Orion_FunctionHook2.self
        ]
    )
}
