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

    private class Dummy {}

    func testStrongRef() {
        let obj = MyClass()

        weak var dummy: Dummy?
        autoreleasepool {
            autoreleasepool {
                let dummyShadow = Dummy()
                dummy = dummyShadow
                Ivars(obj)._strongRef = dummyShadow
            }
            XCTAssertNotNil(dummy)
        }
        XCTAssertNotNil(dummy)

        autoreleasepool {
            Ivars(obj)._strongRef = Dummy()
        }
        XCTAssertNil(dummy)
    }

    func testWeakRefDeallocation() {
        let obj = MyClass()

        weak var dummyWeak: Dummy?
        autoreleasepool {
            let dummyShadow = Dummy()
            dummyWeak = dummyShadow
            Ivars<Dummy?>(obj, .weak)._weakRef = dummyShadow
        }

        XCTAssertNil(dummyWeak)
        XCTAssertNil(Ivars<Dummy?>(obj, .weak)._weakRef)
    }

    func testWeakRefRetention() {
        let obj = MyClass()

        var dummyStrong: Dummy?

        autoreleasepool {
            autoreleasepool {
                let dummyShadow = Dummy()
                dummyStrong = dummyShadow
                Ivars<Dummy?>(obj, .weak)._weakRef = dummyShadow
            }

            XCTAssertNotNil(Ivars<Dummy?>(obj, .weak)._weakRef)
            XCTAssertNotNil(dummyStrong)

            dummyStrong = nil
        }

        XCTAssertNil(Ivars<Dummy?>(obj, .weak)._weakRef)
    }

    func testWeakSafelyAccessing() {
        let obj = MyClass()
        XCTAssertEqual(Ivars<NSString?>(obj)[safelyAccessing: "nonExistentIvar"], NSString??.none)
    }

}
