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
