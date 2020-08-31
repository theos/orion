import XCTest
import Orion
import OrionTestSupport

final class IvarsTests: XCTestCase {

    func testHookIvar() throws {
        let obj = MyClass()
        obj.foo = 2
        obj.bar = -3
        obj.baz = "Hello"
        obj.woz = nil

        XCTAssertNil(Ivars<Int>(obj)[safelyAccessing: "_shouldNotExist"])
        try Ivars<Int>(obj).withIvar("_foo") { ptr in
            let unwrapped = try XCTUnwrap(ptr)
            XCTAssertEqual(unwrapped.pointee, 2)
            unwrapped.pointee = 8
        }
        XCTAssertEqual(obj.foo, 8)

        XCTAssertEqual(Ivars(obj)._bar, -3)
        Ivars(obj)._bar = 12
        XCTAssertEqual(obj.bar, 12)

        XCTAssertEqual(Ivars(obj)._baz, "Hello" as NSString)
        Ivars<NSString>(obj)._baz = "bye"
        XCTAssertEqual(obj.baz, "bye")

        XCTAssertEqual(Ivars(obj)._woz, NSString?.none)
        Ivars<NSString?>(obj)._woz = "niak"
        XCTAssertEqual(obj.woz, "niak")
        Ivars<NSString?>(obj)._woz = nil
        XCTAssertNil(obj.woz)
    }

}
