import XCTest
import Orion
import OrionTestSupport

// NOTE: We don't need the linux testing stuff here because the
// runtime can only be built on platforms with Objective-C

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
