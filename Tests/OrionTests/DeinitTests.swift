import XCTest
import Orion
import OrionTestSupport

private struct Deallocation: Equatable {
    let identifier: String
    let cls: AnyClass

    init(_ identifier: String, _ cls: AnyClass) {
        self.identifier = identifier
        self.cls = cls
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.identifier == rhs.identifier
            && ObjectIdentifier(lhs.cls) == ObjectIdentifier(rhs.cls)
    }
}

private class MockWatcher: NSObject, DeWatcher {
    var deallocations: [Deallocation] = []

    func classWillDeallocate(withIdentifier identifier: String, cls: AnyClass) {
        deallocations.append(Deallocation(identifier, cls))
    }
}

final class DeinitTests: XCTestCase {
    private var watcher: MockWatcher!

    override func setUp() {
        super.setUp()
        watcher = MockWatcher()
        DeClass.watcher = watcher
    }

    override func tearDown() {
        watcher = nil
        DeClass.watcher = nil
        super.tearDown()
    }

    func testRoot() {
        weak var weakObj: DeClass?
        autoreleasepool {
            let obj = DeClass(identifier: "a")
            weakObj = obj
            XCTAssertNotNil(weakObj)
            XCTAssert(watcher.deallocations.isEmpty)
            _ = obj.identifier
        }
        XCTAssertNil(weakObj)
        XCTAssertEqual(watcher.deallocations, [Deallocation("a", DeHook.self), Deallocation("a", DeClass.self)])
    }

    func testSubclass1() {
        weak var weakObj: DeSubclass1?
        autoreleasepool {
            let obj = DeSubclass1(identifier: "b")
            weakObj = obj
            XCTAssertNotNil(weakObj)
            XCTAssert(watcher.deallocations.isEmpty)
            _ = obj.identifier
        }
        XCTAssertNil(weakObj)
        XCTAssertEqual(
            watcher.deallocations,
            [
                Deallocation("b", DeSubHook1.self), Deallocation("b", DeSubclass1.self),
                Deallocation("b", DeHook.self), Deallocation("b", DeClass.self)
            ]
        )
    }

    func testSubclass2() {
        weak var weakObj: DeSubclass2?
        autoreleasepool {
            let obj = DeSubclass2(identifier: "c")
            weakObj = obj
            XCTAssertNotNil(weakObj)
            XCTAssert(watcher.deallocations.isEmpty)
            _ = obj.identifier
        }
        XCTAssertNil(weakObj)
        XCTAssertEqual(
            watcher.deallocations,
            [Deallocation("c", DeSubHook2.self), Deallocation("c", DeHook.self), Deallocation("c", DeClass.self)],
            "callSupr should skip orig call"
        )
    }
}
