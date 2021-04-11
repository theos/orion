import XCTest
@testable import Orion
import OrionTestSupport

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

private struct Foo {
    struct Bar {
        let val: Int
    }
    let bar: Bar
    let distinct: Int
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

    func testPropertyKeys() {
        let first = \Foo.bar.val
        // equivalent to \Foo.bar.val, but since we're not using the same literal
        // it won't be uniqued by the compiler and thus the address of `second` will
        // be a different from `first`
        let second = (\Foo.bar).appending(path: \.val)
        let third = \Foo.distinct

        let firstKey = PropertyKeys.shared.key(for: first)
        let secondKey = PropertyKeys.shared.key(for: second)
        let thirdKey = PropertyKeys.shared.key(for: third)

        XCTAssertEqual(firstKey, secondKey)
        XCTAssertNotEqual(firstKey, thirdKey)
        XCTAssertNotEqual(secondKey, thirdKey)
    }

}
