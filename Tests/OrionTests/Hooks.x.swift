// NOTE: Run generate-test-fixtures every time this file is updated, in order
// to keep the glue in sync.

import Foundation
import Orion
import OrionBackend_Fishhook
import OrionTestSupport

struct HooksTweak: TweakWithBackend {
    static let backend = Backends.Fishhook<Backends.Internal>()

    init() {
        print("Entry!")
    }

    func tweakDidActivate() {
        print("Activated!")
    }
}

class AtoiHook: FunctionHook {
    static let target = Function.symbol("atoi", image: nil)

    func function(_ string: UnsafePointer<Int8>) -> Int32 {
        if strcmp(string, "1234") == 0 || strcmp(string, "2345") == 0 {
            return 10 * orig.function(string)
        } else {
            return orig.function(string)
        }
    }
}

class AtofHook: FunctionHook {
    // When using the internal generator, this unfortunately doesn't actually guarantee that the hooked
    // symbol will be in the provided image. It does guarantee that the image *has* a function with the
    // given name though, but due to two level namespacing fishhook may end up hooking functions by the
    // same name in other images as well
    static let target = Function.symbol("atof", image: "/usr/lib/libc.dylib")

    func function(_ string: UnsafePointer<Int8>) -> Double {
        if strcmp(string, "1.5") == 0 || strcmp(string, "2.5") == 0 {
            return 10 * orig.function(string)
        } else {
            return orig.function(string)
        }
    }
}

class BasicHook: ClassHook<BasicClass> {
    func someTestMethod() -> String {
        "Hooked test method"
    }

    func someTestMethod(withArgument argument: Int32) -> String {
        "Hooked: \(orig.someTestMethod(withArgument: argument + 1))"
    }

    class func someTestMethod2(withArgument argument: Int32) -> String {
        "Hooked class method: \(orig.someTestMethod2(withArgument: argument + 1))"
    }
}

class ActivationHook: ClassHook<BasicClass> {
    static var activationSteps = ["not activated"]

    static func hookWillActivate() -> Bool {
        activationSteps.append("will activate called")
        return true
    }

    static func hookDidActivate() {
        activationSteps.append("did activate called")
    }

    func someDidActivateMethod() -> String {
        Self.activationSteps.joined(separator: ", ")
    }
}

class NotHook: ClassHook<BasicClass> {
    static let targetName = "NonExistentClass"

    static func hookWillActivate() -> Bool {
        false
    }

    func someUnhookedMethod() -> String {
        "Hooked unhooked method, oops"
    }
}

class NamedBasicHook: ClassHook<NSObject> {
    static let targetName = "BasicClass"

    func methodForNamedTest() -> Bool { true }

    class func classMethodForNamedTest(withArgument arg: String) -> [String] {
        let origVal = orig.classMethodForNamedTest(withArgument: "\(arg), or is it")
        return ["Hooked named class method"] + origVal
    }
}

class BasicSubclass: ClassHook<BasicClass> {
    static let subclassMode = SubclassMode.createSubclassNamed("CustomBasicSubclass")

    static var protocols: [Protocol] {
        // we could use NewMethodProtocol.self but this also tests `Dynamic.protocol`
        [Dynamic.OrionTests.NewMethodProtocol.protocol]
    }

    // this ensures that the method is added to the *subclass* and doesn't
    // swizzle the superclass imp. If it did swizzle the original, we'd
    // know because the test for the actual `someTestMethod` would fail
    func someTestMethod() -> String {
        "Subclassed test method"
    }

    final func someNewMethod() -> String {
        "New method"
    }

    func subclassableTestMethod() -> String {
        "Subclassed: \(supr.subclassableTestMethod())"
    }

    class func subclassableTestMethod1() -> String {
        "Subclassed class: \(supr.subclassableTestMethod1())"
    }
}

class NamedBasicSubclass: ClassHook<NSObject> {
    static let targetName = "BasicClass"
    static let subclassMode = SubclassMode.createSubclass

    func subclassableNamedTestMethod() -> String {
        "Subclassed named: \(supr.subclassableNamedTestMethod())"
    }

    class func subclassableNamedTestMethod1() -> String {
        "Subclassed named class: \(supr.subclassableNamedTestMethod1())"
    }
}

class AdditionHook: ClassHook<BasicClass> {
    final func someTestProtocolMethod() -> String {
        "New method"
    }

    final class func someTestProtocolClassMethod() -> String {
        "New class method"
    }
}

class InheritedHook: ClassHook<InheritedClass> {
    class func someTestMethod3() -> String {
        "Hooked test class method: \(supr.someTestMethod3())"
    }
}

class InitHook: ClassHook<InitClass> {
    // just a placeholder to allow forwarding
    func `init`() -> Target { orig.`init`() }

    func `init`(withX x: Int32) -> Target {
        let this = supr.`init`()
        Ivars(this)._x = x + 1
        return this
    }
}

class SuperHook: ClassHook<MyClass> {
    @Property(.nonatomic) var x = 11

    func description() -> String {
        "hax description: \(supr.description())"
    }

    func hooked() -> String {
        if x == 0 {
            return "zero"
        } else {
            x -= 1
            return "orig: \(orig.hooked()). hax hooked \(supr.description()). x=\(x), prev=\(hooked())"
        }
    }
}

class PropertyHookX: ClassHook<PropertyClass> {
    @Property(.nonatomic) var x = 1

    func getXValue() -> Int { x }
    func setXValue(_ x: Int) { self.x = x }
}

class PropertyHookY: ClassHook<PropertyClass> {
    @Property(.nonatomic) var x = 1

    func getYValue() -> Int { x }

    func setYValue(_ x: Int) {
        self.x = x
    }
}

class PropertyHook2: ClassHook<PropertyClass2> {
    @Property(.nonatomic) var x = 1

    func getXValue() -> Int { x }

    func setXValue(_ x: Int) {
        self.x = x
    }
}

class DeHook: ClassHook<DeClass> {
    func deinitializer() -> DeinitPolicy {
        Self.target.watcher?.classWillDeallocate(withIdentifier: target.identifier, cls: DeHook.self)
        return .callOrig
    }
}

class DeSubHook1: ClassHook<DeSubclass1> {
    // final just to ensure that we can adapt when a deinitializer is `final`
    // (even though it makes no effective difference)
    final func deinitializer() -> DeinitPolicy {
        Self.target.watcher?.classWillDeallocate(withIdentifier: target.identifier, cls: DeSubHook1.self)
        return .callOrig
    }
}

class DeSubHook2: ClassHook<DeSubclass2> {
    func deinitializer() -> DeinitPolicy {
        Self.target.watcher?.classWillDeallocate(withIdentifier: target.identifier, cls: DeSubHook2.self)
        return .callSupr
    }
}

struct MyGroup: HookGroup {
    let className: String
    let param: Int
}

class GrHook: ClassHook<NSObject> {
    typealias Group = MyGroup

    static let targetName = group.className

    func myString() -> String {
        "New group string with param: \(Self.group.param)"
    }
}

class GrHook2: ClassHook<NSObject> {
    typealias Group = MyGroup

    static let targetName = group.className

    func mySecondString() -> String {
        "New second group string with param: \(Self.group.param)"
    }
}

struct MySecondGroup: HookGroup {
    let secondClassName: String
    let secondParam: Double
}

class GrHook3: ClassHook<NSObject> {
    typealias Group = MySecondGroup

    static let targetName = group.secondClassName

    func myThirdString() -> String {
        "New third group string with param: \(Self.group.secondParam)"
    }
}

struct StringCompareGroup: HookGroup {
    let stringToOverride: String
}

class StringCompareHook: FunctionHook {
    typealias Group = StringCompareGroup

    static let target = Function.symbol("strcmp", image: nil)

    func function(_ s1: UnsafePointer<Int8>?, _ s2: UnsafePointer<Int8>?) -> Int32 {
        if let s1 = s1,
           let s2 = s2,
           String(cString: s1) == Self.group.stringToOverride ||
            String(cString: s2) == Self.group.stringToOverride {
            return 42
        } else {
            return orig.function(s1, s2)
        }
    }
}
