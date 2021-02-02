import XCTest
import Orion
import OrionTestSupport

final class GroupTests: XCTestCase {

    func testClassHookGroups() {
        let obj = GroupClass()
        XCTAssertEqual(obj.myString(), "Original group string", "MyGroup was prematurely activated")
        XCTAssertEqual(obj.mySecondString(), "Original second group string", "MyGroup was prematurely activated")
        XCTAssertEqual(obj.myThirdString(), "Original third group string", "MySecondGroup was prematurely activated")
        XCTAssertFalse(MyGroup.isActive)
        MyGroup(className: "GroupClass", param: 5).activate()
        XCTAssertTrue(MyGroup.isActive)
        XCTAssertEqual(obj.myString(), "New group string with param: 5", "MyGroup was not activated")
        XCTAssertEqual(obj.mySecondString(), "New second group string with param: 5", "MyGroup was not activated")
        XCTAssertEqual(obj.myThirdString(), "Original third group string", "MySecondGroup was prematurely activated")
        MySecondGroup(secondClassName: "GroupClass", secondParam: 42.5).activate()
        XCTAssertEqual(obj.myThirdString(), "New third group string with param: 42.5", "MySecondGroup was not activated")
    }

    func testFunctionHookGroups() {
        XCTAssertEqual(strcmp("orionfoo", "test"), -5)
        XCTAssertEqual(strcmp("xyz", "abc"), 23)
        StringCompareGroup(stringToOverride: "orionfoo").activate()
        XCTAssertEqual(strcmp("orionfoo", "test"), 42)
        XCTAssertEqual(strcmp("xyz", "abc"), 23)
    }

}
