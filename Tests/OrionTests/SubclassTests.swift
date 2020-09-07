import XCTest
import Orion
import OrionTestSupport

@objc protocol NewMethodProtocol {
    func someNewMethod() -> String
}

final class SubclassTests: XCTestCase {

    func testCustomSubclassNameRespected() {
        XCTAssertNotNil(NSClassFromString("CustomBasicSubclass") as? BasicClass.Type)
    }

    func testDefaultSubclassName() {
        XCTAssertNotNil(NSClassFromString("OrionSubclass.OrionTests.NamedBasicSubclass") as? BasicClass.Type)
    }

    func testOverriddenHookedMethod() {
        let obj = BasicSubclass.target.init()
        XCTAssertEqual(obj.someTestMethod(), "Subclassed test method")
    }

    func testNewMethod() throws {
        let obj = BasicSubclass.target.init()
        // doubles as a check to ensure ClassHookWithProtocols works
        let asProtocol = try XCTUnwrap(obj as? NewMethodProtocol, "BasicSubclass' target should conform to NewMethodProtocol")
        XCTAssertEqual(asProtocol.someNewMethod(), "New method")
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
