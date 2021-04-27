import XCTest
import Orion
import OrionTestSupport

// NOTE: We don't need the linux testing stuff here because the
// runtime can only be built on platforms with Objective-C

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

class InheritedHook: ClassHook<InheritedClass> {
    class func someTestMethod3() -> String {
        "Hooked test class method: \(supr.someTestMethod3())"
    }
}

class InitHook: ClassHook<InitClass> {
    // orion:supr_tramp
    func `init`() -> Target { fatalError() }

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

class CPHook: ClassHook<MyCopyClass> {
    func copy() -> Target {
        let cp = Target()
        Ivars(cp)._x = target.x + 10
        return cp
    }

    func mutableCopy() -> Target {
        let cp = orig.mutableCopy()
        Ivars(cp)._x += 100
        return cp
    }
}

final class ClassHookTests: XCTestCase {
    func testBasicDirectInstanceHooks() {
        let basic = BasicClass()
        XCTAssertEqual(basic.someTestMethod(), "Hooked test method", "Basic instance methods should be hookable")
        XCTAssertEqual(
            basic.someTestMethod(withArgument: 5),
            "Hooked: Original test method with arg 6",
            "Instance methods with arguments should be hookable"
        )
    }

    func testBasicDirectClassHooks() {
        XCTAssertEqual(
            BasicClass.someTestMethod2(withArgument: 3),
            "Hooked class method: Original test class method with arg 4",
            "Class methods should be hookable"
        )
    }

    func testBasicNamedInstanceHooks() {
        let basic = BasicClass()
        XCTAssertTrue(basic.methodForNamedTest(), "ClassHookWithTargetName should work on instance methods")
    }

    func testBasicNamedClassHooks() {
        // swiftlint:disable:next force_cast
        let res = BasicClass.classMethodForNamedTest(withArgument: "Orion") as! [String]
        XCTAssertEqual(res, ["Hooked named class method", "hello", "Orion, or is it!"])
    }

    func testDidActivateCalled() {
        // if ActivationHook has been initialized correctly, hookWillActivate should be called, and then
        // hookDidActivate, resulting in the output text being in the following order
        XCTAssertEqual(BasicClass().someDidActivateMethod(), "not activated, will activate called, did activate called")
    }

    func testUnhookedMethod() {
        // since NotHook.hookWillActivate returns false, this method should *not* be hooked
        XCTAssertEqual(BasicClass().someUnhookedMethod(), "Original unhooked method")
    }

    func testInheritedSuperClassHooks() {
        // test for calling supr on a class method
        let res = InheritedClass.someTestMethod3()
        XCTAssertEqual(res, "Hooked test class method: Base test class method")
    }

    func testInitHook() {
        let cls = InitClass(x: 5)
        switch cls.initType {
        case .none:
            break
        case .regular:
            XCTFail("Hook called -[InitClass init] instead of -[NSObject init]")
        case .withX:
            XCTFail("Hook did not prevent original -[InitClass initWithX:] from being called")
        }
        XCTAssertEqual(cls.x, 6)
    }

    func testPlusOneOverRelease() throws {
        weak var cp: MyCopyClass?
        try autoreleasepool {
            let obj = MyCopyClass()
            let copy = try XCTUnwrap(obj.copy() as? MyCopyClass)
            XCTAssertEqual(copy.x, 15, "-copy may not have been swizzled")
            // the extra retain will result in the weak reference
            // being non-nil unless there's an overrelease
            cp = Unmanaged.passUnretained(copy).retain().takeUnretainedValue()
        }
        XCTAssertNotNil(cp, "-copy resulted in an extra release")
        if let nonNilCP = cp {
            // balance the extra retain
            _ = Unmanaged.passRetained(nonNilCP)
        }
    }

    func testPlusOneNoLeak() throws {
        weak var weakCP: MyCopyClass?
        try autoreleasepool {
            let cp = try XCTUnwrap(MyCopyClass().copy() as? MyCopyClass)
            weakCP = cp
        }
        XCTAssertNil(weakCP, "copy (no orig) resulted in an extra retain")
    }

    func testPlusOneOrigNoCrash() throws {
        let obj = MyCopyClass()
        let cp = try XCTUnwrap(autoreleasepool(invoking: obj.mutableCopy) as? MyCopyClass)
        XCTAssertEqual(cp.x, 199, "-mutableCopy may not have been swizzled")
    }

    func testPlusOneOrigNoLeak() throws {
        weak var weakCP: MyCopyClass?
        try autoreleasepool {
            let cp = try XCTUnwrap(MyCopyClass().mutableCopy() as? MyCopyClass)
            weakCP = cp
        }
        XCTAssertNil(weakCP, "mutableCopy (with orig) resulted in an extraneous retain")
    }

    func testSuper() {
        let cls = MyClass()
        let desc = cls.description
        XCTAssert(desc.hasPrefix("hax description: <MyClass: 0x"))
    }

    func testSuperSecond() {
        let cls = MyClass()
        let hooked = cls.hooked
        XCTAssert(hooked.hasPrefix("orig: regular hooked. hax hooked <MyClass: 0x"))
        XCTAssert(hooked.hasSuffix(">. x=0, prev=zero"))
    }
}
