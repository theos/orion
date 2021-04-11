import XCTest
import Orion
import OrionTestSupport

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
