import XCTest
import Orion
import OrionTestSupport

class BasicSubclass: ClassHook<BasicClass> {
    static let subclassMode = SubclassMode.createSubclassNamed("CustomBasicSubclass")

    static var protocols: [Protocol] {
        // we could use NewMethodProtocol.self but this also tests `Dynamic.protocol`
        [Dynamic.OrionTests.NewMethodProtocol.protocol]
    }

    // this ensures that the method is added to the *subclass* and doesn't
    // swizzle the superclass imp. If it did swizzle the original, we'd
    // know because the test for the actual `someTestMethod` would fail
    func someTestMethod() -> String {
        "Subclassed test method"
    }

    /* orion:new */ func someNewMethod() -> String {
        "New method"
    }

    func subclassableTestMethod() -> String {
        "Subclassed: \(supr.subclassableTestMethod())"
    }

    class func subclassableTestMethod1() -> String {
        "Subclassed class: \(supr.subclassableTestMethod1())"
    }
}

class NamedBasicSubclass: ClassHook<NSObject> {
    static let targetName = "BasicClass"
    static let subclassMode = SubclassMode.createSubclass

    func subclassableNamedTestMethod() -> String {
        "Subclassed named: \(supr.subclassableNamedTestMethod())"
    }

    class func subclassableNamedTestMethod1() -> String {
        "Subclassed named class: \(supr.subclassableNamedTestMethod1())"
    }
}

@objc protocol NewMethodProtocol {
    func someNewMethod() -> String
}

// swiftlint:disable explicit_init

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

// swiftlint:enable explicit_init
