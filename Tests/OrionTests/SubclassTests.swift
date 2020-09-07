import XCTest
import Orion
import OrionTestSupport

@objc protocol NewMethodInterface {
    @objc optional func someNewMethod() -> String
}

final class SubclassTests: XCTestCase {

    func testOverriddenHookedMethod() {
        let obj = BasicSubclass.target.init()
        XCTAssertEqual(obj.someTestMethod(), "Subclassed test method")
    }

    func testNewMethod() {
        let obj = BasicSubclass.target.init()
        XCTAssertEqual(obj.as(interface: NewMethodInterface.self).someNewMethod?(), "New method")
    }

    func testBasicSubclassInstanceMethod() {
        let obj = BasicSubclass.target.init()
        XCTAssertEqual(obj.subclassableTestMethod(), "Subclassed: Subclassable test method")
    }

    func testBasicSubclassClassMethod() {
        XCTAssertEqual(BasicSubclass.target.subclassableTestMethod1(), "Subclassed class: Subclassable test class method")
    }

    func testNamedBasicSubclassInstanceMethod() throws {
        let obj = try XCTUnwrap(NamedBasicSubclass.target.init() as? BasicClass)
        XCTAssertEqual(obj.subclassableNamedTestMethod(), "Subclassed named: Subclassable named test method")
    }

    func testNamedBasicSubclassClassMethod() throws {
        let obj = try XCTUnwrap(NamedBasicSubclass.target as? BasicClass.Type)
        XCTAssertEqual(obj.subclassableNamedTestMethod1(), "Subclassed named class: Subclassable named test class method")
    }

}
