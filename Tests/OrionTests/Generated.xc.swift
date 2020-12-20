// swiftlint:disable all

import Foundation
import Orion
import OrionBackend_Fishhook
import OrionTestSupport

extension BasicHook {
    public static let _target: BasicClass.Type = _initializeTargetType()
}

private class Orion_ClassHook1: BasicHook, _GlueClassHook {
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

    static func activate(withClassHookBuilder builder: inout _ClassHookBuilder) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        builder.addHook(orion_sel2, orion_orig2, isClassMethod: false) { orion_orig2 = $0 }
        builder.addHook(orion_sel3, orion_orig3, isClassMethod: true) { orion_orig3 = $0 }
    }
}

extension ActivationHook {
    public static let _target: BasicClass.Type = _initializeTargetType()
}

private class Orion_ClassHook2: ActivationHook, _GlueClassHook {
    final class OrigType: Orion_ClassHook2 {
        @objc override func someDidActivateMethod() -> String {
            Self.orion_orig1(target, Self.orion_sel1)
        }
    }

    final class SuprType: Orion_ClassHook2 {
        @objc override func someDidActivateMethod() -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel1) }
        }
    }

    private static let orion_sel1 = #selector(someDidActivateMethod as (Self) -> () -> String)
    private static var orion_orig1: @convention(c) (Target, Selector) -> String = { target, _cmd in
        Orion_ClassHook2(target: target).someDidActivateMethod()
    }

    static func activate(withClassHookBuilder builder: inout _ClassHookBuilder) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
    }
}

extension NotHook {
    public static let _target: BasicClass.Type = _initializeTargetType()
}

private class Orion_ClassHook3: NotHook, _GlueClassHook {
    final class OrigType: Orion_ClassHook3 {
        @objc override func someUnhookedMethod() -> String {
            Self.orion_orig1(target, Self.orion_sel1)
        }
    }

    final class SuprType: Orion_ClassHook3 {
        @objc override func someUnhookedMethod() -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel1) }
        }
    }

    private static let orion_sel1 = #selector(someUnhookedMethod as (Self) -> () -> String)
    private static var orion_orig1: @convention(c) (Target, Selector) -> String = { target, _cmd in
        Orion_ClassHook3(target: target).someUnhookedMethod()
    }

    static func activate(withClassHookBuilder builder: inout _ClassHookBuilder) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
    }
}

extension NamedBasicHook {
    public static let _target: NSObject.Type = _initializeTargetType()
}

private class Orion_ClassHook4: NamedBasicHook, _GlueClassHook {
    final class OrigType: Orion_ClassHook4 {
        @objc override func methodForNamedTest() -> Bool {
            Self.orion_orig1(target, Self.orion_sel1)
        }

        @objc class override func classMethodForNamedTest(withArgument arg1: String) -> [String] {
            Self.orion_orig2(target, Self.orion_sel2, arg1)
        }
    }

    final class SuprType: Orion_ClassHook4 {
        @objc override func methodForNamedTest() -> Bool {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> Bool).self) { $0($1, Self.orion_sel1) }
        }

        @objc class override func classMethodForNamedTest(withArgument arg1: String) -> [String] {
            callSuper((@convention(c) (UnsafeRawPointer, Selector, String) -> [String]).self) { $0($1, Self.orion_sel2, arg1) }
        }
    }

    private static let orion_sel1 = #selector(methodForNamedTest as (Self) -> () -> Bool)
    private static var orion_orig1: @convention(c) (Target, Selector) -> Bool = { target, _cmd in
        Orion_ClassHook4(target: target).methodForNamedTest()
    }

    private static let orion_sel2 = #selector(classMethodForNamedTest(withArgument:) as (String) -> [String])
    private static var orion_orig2: @convention(c) (AnyClass, Selector, String) -> [String] = { target, _cmd, arg1 in
        Orion_ClassHook4.classMethodForNamedTest(withArgument:)(arg1)
    }

    static func activate(withClassHookBuilder builder: inout _ClassHookBuilder) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        builder.addHook(orion_sel2, orion_orig2, isClassMethod: true) { orion_orig2 = $0 }
    }
}

extension BasicSubclass {
    public static let _target: BasicClass.Type = _initializeTargetType()
}

private class Orion_ClassHook5: BasicSubclass, _GlueClassHook {
    final class OrigType: Orion_ClassHook5 {
        @objc override func someTestMethod() -> String {
            Self.orion_orig1(target, Self.orion_sel1)
        }

        @objc override func subclassableTestMethod() -> String {
            Self.orion_orig3(target, Self.orion_sel3)
        }

        @objc class override func subclassableTestMethod1() -> String {
            Self.orion_orig4(target, Self.orion_sel4)
        }
    }

    final class SuprType: Orion_ClassHook5 {
        @objc override func someTestMethod() -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel1) }
        }

        @objc override func subclassableTestMethod() -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel3) }
        }

        @objc class override func subclassableTestMethod1() -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel4) }
        }
    }

    private static let orion_sel1 = #selector(someTestMethod as (Self) -> () -> String)
    private static var orion_orig1: @convention(c) (Target, Selector) -> String = { target, _cmd in
        Orion_ClassHook5(target: target).someTestMethod()
    }

    private static let orion_sel2 = #selector(someNewMethod as (Self) -> () -> String)
    private static var orion_imp2: @convention(c) (Target, Selector) -> String = { target, _cmd in
        Orion_ClassHook5(target: target).someNewMethod()
    }

    private static let orion_sel3 = #selector(subclassableTestMethod as (Self) -> () -> String)
    private static var orion_orig3: @convention(c) (Target, Selector) -> String = { target, _cmd in
        Orion_ClassHook5(target: target).subclassableTestMethod()
    }

    private static let orion_sel4 = #selector(subclassableTestMethod1 as () -> String)
    private static var orion_orig4: @convention(c) (AnyClass, Selector) -> String = { target, _cmd in
        Orion_ClassHook5.subclassableTestMethod1()
    }

    static func activate(withClassHookBuilder builder: inout _ClassHookBuilder) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        addMethod(orion_sel2, orion_imp2, isClassMethod: false)
        builder.addHook(orion_sel3, orion_orig3, isClassMethod: false) { orion_orig3 = $0 }
        builder.addHook(orion_sel4, orion_orig4, isClassMethod: true) { orion_orig4 = $0 }
    }
}

extension NamedBasicSubclass {
    public static let _target: NSObject.Type = _initializeTargetType()
}

private class Orion_ClassHook6: NamedBasicSubclass, _GlueClassHook {
    final class OrigType: Orion_ClassHook6 {
        @objc override func subclassableNamedTestMethod() -> String {
            Self.orion_orig1(target, Self.orion_sel1)
        }

        @objc class override func subclassableNamedTestMethod1() -> String {
            Self.orion_orig2(target, Self.orion_sel2)
        }
    }

    final class SuprType: Orion_ClassHook6 {
        @objc override func subclassableNamedTestMethod() -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel1) }
        }

        @objc class override func subclassableNamedTestMethod1() -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel2) }
        }
    }

    private static let orion_sel1 = #selector(subclassableNamedTestMethod as (Self) -> () -> String)
    private static var orion_orig1: @convention(c) (Target, Selector) -> String = { target, _cmd in
        Orion_ClassHook6(target: target).subclassableNamedTestMethod()
    }

    private static let orion_sel2 = #selector(subclassableNamedTestMethod1 as () -> String)
    private static var orion_orig2: @convention(c) (AnyClass, Selector) -> String = { target, _cmd in
        Orion_ClassHook6.subclassableNamedTestMethod1()
    }

    static func activate(withClassHookBuilder builder: inout _ClassHookBuilder) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        builder.addHook(orion_sel2, orion_orig2, isClassMethod: true) { orion_orig2 = $0 }
    }
}

extension AdditionHook {
    public static let _target: BasicClass.Type = _initializeTargetType()
}

private class Orion_ClassHook7: AdditionHook, _GlueClassHook {
    final class OrigType: Orion_ClassHook7 {}

    final class SuprType: Orion_ClassHook7 {}

    private static let orion_sel1 = #selector(someTestProtocolMethod as (Self) -> () -> String)
    private static var orion_imp1: @convention(c) (Target, Selector) -> String = { target, _cmd in
        Orion_ClassHook7(target: target).someTestProtocolMethod()
    }

    private static let orion_sel2 = #selector(someTestProtocolClassMethod as () -> String)
    private static var orion_imp2: @convention(c) (AnyClass, Selector) -> String = { target, _cmd in
        Orion_ClassHook7.someTestProtocolClassMethod()
    }

    static func activate(withClassHookBuilder builder: inout _ClassHookBuilder) {
        addMethod(orion_sel1, orion_imp1, isClassMethod: false)
        addMethod(orion_sel2, orion_imp2, isClassMethod: true)
    }
}

extension InheritedHook {
    public static let _target: InheritedClass.Type = _initializeTargetType()
}

private class Orion_ClassHook8: InheritedHook, _GlueClassHook {
    final class OrigType: Orion_ClassHook8 {
        @objc class override func someTestMethod3() -> String {
            Self.orion_orig1(target, Self.orion_sel1)
        }
    }

    final class SuprType: Orion_ClassHook8 {
        @objc class override func someTestMethod3() -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel1) }
        }
    }

    private static let orion_sel1 = #selector(someTestMethod3 as () -> String)
    private static var orion_orig1: @convention(c) (AnyClass, Selector) -> String = { target, _cmd in
        Orion_ClassHook8.someTestMethod3()
    }

    static func activate(withClassHookBuilder builder: inout _ClassHookBuilder) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: true) { orion_orig1 = $0 }
    }
}

extension InitHook {
    public static let _target: InitClass.Type = _initializeTargetType()
}

private class Orion_ClassHook9: InitHook, _GlueClassHook {
    final class OrigType: Orion_ClassHook9 {
        @objc override func `init`() -> Target {
            Self.orion_orig1(target, Self.orion_sel1)
        }

        @objc override func `init`(withX arg1: Int32) -> Target {
            Self.orion_orig2(target, Self.orion_sel2, arg1)
        }
    }

    final class SuprType: Orion_ClassHook9 {
        @objc override func `init`() -> Target {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> Target).self) { $0($1, Self.orion_sel1) }
        }

        @objc override func `init`(withX arg1: Int32) -> Target {
            callSuper((@convention(c) (UnsafeRawPointer, Selector, Int32) -> Target).self) { $0($1, Self.orion_sel2, arg1) }
        }
    }

    private static let orion_sel1 = #selector(`init` as (Self) -> () -> Target)
    private static var orion_orig1: @convention(c) (Target, Selector) -> Target = { target, _cmd in
        Orion_ClassHook9(target: target).`init`()
    }

    private static let orion_sel2 = #selector(`init`(withX:) as (Self) -> (Int32) -> Target)
    private static var orion_orig2: @convention(c) (Target, Selector, Int32) -> Target = { target, _cmd, arg1 in
        Orion_ClassHook9(target: target).`init`(withX:)(arg1)
    }

    static func activate(withClassHookBuilder builder: inout _ClassHookBuilder) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        builder.addHook(orion_sel2, orion_orig2, isClassMethod: false) { orion_orig2 = $0 }
    }
}

extension SuperHook {
    public static let _target: MyClass.Type = _initializeTargetType()
}

private class Orion_ClassHook10: SuperHook, _GlueClassHook {
    final class OrigType: Orion_ClassHook10 {
        @objc override func description() -> String {
            Self.orion_orig1(target, Self.orion_sel1)
        }

        @objc override func hooked() -> String {
            Self.orion_orig2(target, Self.orion_sel2)
        }
    }

    final class SuprType: Orion_ClassHook10 {
        @objc override func description() -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel1) }
        }

        @objc override func hooked() -> String {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> String).self) { $0($1, Self.orion_sel2) }
        }
    }

    private static let orion_sel1 = #selector(description as (Self) -> () -> String)
    private static var orion_orig1: @convention(c) (Target, Selector) -> String = { target, _cmd in
        Orion_ClassHook10(target: target).description()
    }

    private static let orion_sel2 = #selector(hooked as (Self) -> () -> String)
    private static var orion_orig2: @convention(c) (Target, Selector) -> String = { target, _cmd in
        Orion_ClassHook10(target: target).hooked()
    }

    static func activate(withClassHookBuilder builder: inout _ClassHookBuilder) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        builder.addHook(orion_sel2, orion_orig2, isClassMethod: false) { orion_orig2 = $0 }
    }
}

extension PropertyHookX {
    public static let _target: PropertyClass.Type = _initializeTargetType()
}

private class Orion_ClassHook11: PropertyHookX, _GlueClassHook {
    final class OrigType: Orion_ClassHook11 {
        @objc override func getXValue() -> Int {
            Self.orion_orig1(target, Self.orion_sel1)
        }

        @objc override func setXValue(_ arg1: Int)  {
            Self.orion_orig2(target, Self.orion_sel2, arg1)
        }
    }

    final class SuprType: Orion_ClassHook11 {
        @objc override func getXValue() -> Int {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> Int).self) { $0($1, Self.orion_sel1) }
        }

        @objc override func setXValue(_ arg1: Int)  {
            callSuper((@convention(c) (UnsafeRawPointer, Selector, Int) -> Void).self) { $0($1, Self.orion_sel2, arg1) }
        }
    }

    private static let orion_sel1 = #selector(getXValue as (Self) -> () -> Int)
    private static var orion_orig1: @convention(c) (Target, Selector) -> Int = { target, _cmd in
        Orion_ClassHook11(target: target).getXValue()
    }

    private static let orion_sel2 = #selector(setXValue(_:) as (Self) -> (Int) -> Void)
    private static var orion_orig2: @convention(c) (Target, Selector, Int) -> Void = { target, _cmd, arg1 in
        Orion_ClassHook11(target: target).setXValue(_:)(arg1)
    }

    static func activate(withClassHookBuilder builder: inout _ClassHookBuilder) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        builder.addHook(orion_sel2, orion_orig2, isClassMethod: false) { orion_orig2 = $0 }
    }
}

extension PropertyHookY {
    public static let _target: PropertyClass.Type = _initializeTargetType()
}

private class Orion_ClassHook12: PropertyHookY, _GlueClassHook {
    final class OrigType: Orion_ClassHook12 {
        @objc override func getYValue() -> Int {
            Self.orion_orig1(target, Self.orion_sel1)
        }

        @objc override func setYValue(_ arg1: Int)  {
            Self.orion_orig2(target, Self.orion_sel2, arg1)
        }
    }

    final class SuprType: Orion_ClassHook12 {
        @objc override func getYValue() -> Int {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> Int).self) { $0($1, Self.orion_sel1) }
        }

        @objc override func setYValue(_ arg1: Int)  {
            callSuper((@convention(c) (UnsafeRawPointer, Selector, Int) -> Void).self) { $0($1, Self.orion_sel2, arg1) }
        }
    }

    private static let orion_sel1 = #selector(getYValue as (Self) -> () -> Int)
    private static var orion_orig1: @convention(c) (Target, Selector) -> Int = { target, _cmd in
        Orion_ClassHook12(target: target).getYValue()
    }

    private static let orion_sel2 = #selector(setYValue(_:) as (Self) -> (Int) -> Void)
    private static var orion_orig2: @convention(c) (Target, Selector, Int) -> Void = { target, _cmd, arg1 in
        Orion_ClassHook12(target: target).setYValue(_:)(arg1)
    }

    static func activate(withClassHookBuilder builder: inout _ClassHookBuilder) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        builder.addHook(orion_sel2, orion_orig2, isClassMethod: false) { orion_orig2 = $0 }
    }
}

extension PropertyHook2 {
    public static let _target: PropertyClass2.Type = _initializeTargetType()
}

private class Orion_ClassHook13: PropertyHook2, _GlueClassHook {
    final class OrigType: Orion_ClassHook13 {
        @objc override func getXValue() -> Int {
            Self.orion_orig1(target, Self.orion_sel1)
        }

        @objc override func setXValue(_ arg1: Int)  {
            Self.orion_orig2(target, Self.orion_sel2, arg1)
        }
    }

    final class SuprType: Orion_ClassHook13 {
        @objc override func getXValue() -> Int {
            callSuper((@convention(c) (UnsafeRawPointer, Selector) -> Int).self) { $0($1, Self.orion_sel1) }
        }

        @objc override func setXValue(_ arg1: Int)  {
            callSuper((@convention(c) (UnsafeRawPointer, Selector, Int) -> Void).self) { $0($1, Self.orion_sel2, arg1) }
        }
    }

    private static let orion_sel1 = #selector(getXValue as (Self) -> () -> Int)
    private static var orion_orig1: @convention(c) (Target, Selector) -> Int = { target, _cmd in
        Orion_ClassHook13(target: target).getXValue()
    }

    private static let orion_sel2 = #selector(setXValue(_:) as (Self) -> (Int) -> Void)
    private static var orion_orig2: @convention(c) (Target, Selector, Int) -> Void = { target, _cmd, arg1 in
        Orion_ClassHook13(target: target).setXValue(_:)(arg1)
    }

    static func activate(withClassHookBuilder builder: inout _ClassHookBuilder) {
        builder.addHook(orion_sel1, orion_orig1, isClassMethod: false) { orion_orig1 = $0 }
        builder.addHook(orion_sel2, orion_orig2, isClassMethod: false) { orion_orig2 = $0 }
    }
}

private class Orion_FunctionHook1: AtoiHook, _GlueFunctionHook {
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

private class Orion_FunctionHook2: AtofHook, _GlueFunctionHook {
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

@_cdecl("orion_init")
func orion_init() {
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
            Orion_ClassHook9.self,
            Orion_ClassHook10.self,
            Orion_ClassHook11.self,
            Orion_ClassHook12.self,
            Orion_ClassHook13.self,
            Orion_FunctionHook1.self,
            Orion_FunctionHook2.self
        ]
    )
}
