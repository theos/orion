import XCTest
import Orion
import OrionTestSupport

class PropertyHookX: ClassHook<PropertyClass> {
    @Property(.nonatomic) var x = 1

    func getXValue() -> Int { print("getting x"); return x }
    func setXValue(_ x: Int) { print("setting x"); self.x = x }
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

final class PropertyTests: XCTestCase {

    func testBasic() {
        let object = PropertyClass()
        XCTAssertEqual(object.getXValue(), 1)
        object.setXValue(2)
        XCTAssertEqual(object.getXValue(), 2)
    }

    func testMultipleObjects() {
        let object1 = PropertyClass()
        XCTAssertEqual(object1.getXValue(), 1)
        object1.setXValue(2)
        XCTAssertEqual(object1.getXValue(), 2)

        let object2 = PropertyClass()
        XCTAssertEqual(object2.getXValue(), 1)
        object2.setXValue(5)
        XCTAssertEqual(object2.getXValue(), 5)
    }

    func testNoSelectorInterference() {
        let object1 = PropertyClass()
        XCTAssertEqual(object1.getXValue(), 1)
        object1.setXValue(2)
        XCTAssertEqual(object1.getXValue(), 2)

        XCTAssertEqual(
            object1.getYValue(), 1,
            "The @Property associated object key should not simply be determined by the selector"
        )
        object1.setYValue(5)
        XCTAssertEqual(object1.getYValue(), 5)
        XCTAssertEqual(object1.getXValue(), 2)
    }

}
