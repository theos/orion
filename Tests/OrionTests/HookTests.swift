import XCTest
import Orion
import OrionTestSupport

// NOTE: We don't need the linux testing stuff here because the
// runtime can only be built on platforms with Objective-C

final class HookTests: XCTestCase {
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
        XCTAssertTrue(basic.methodForNamedTest(), "NamedClassHook should work on instance methods")
    }

    func testBasicNamedClassHooks() {
        let res = BasicClass.classMethodForNamedTest(withArgument: "Orion") as! [String]
        XCTAssertEqual(res, ["Hooked named class method", "hello", "Orion, or is it!"])
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
        XCTAssertEqual(hooked.count, 742)
    }
}
