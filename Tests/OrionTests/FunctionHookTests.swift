import XCTest
import Orion
import OrionTestSupport

class AtoiHook: FunctionHook {
    static let target = Function.symbol("atoi", image: nil)

    func function(_ string: UnsafePointer<Int8>) -> Int32 {
        if strcmp(string, "1234") == 0 || strcmp(string, "2345") == 0 {
            return 10 * orig.function(string)
        } else {
            return orig.function(string)
        }
    }
}

class AtofHook: FunctionHook {
    // When using the internal generator, this unfortunately doesn't actually guarantee that the hooked
    // symbol will be in the provided image. It does guarantee that the image *has* a function with the
    // given name though, but due to two level namespacing fishhook may end up hooking functions by the
    // same name in other images as well
    static let target = Function.symbol("atof", image: "/usr/lib/libc.dylib")

    func function(_ string: UnsafePointer<Int8>) -> Double {
        if strcmp(string, "1.5") == 0 || strcmp(string, "2.5") == 0 {
            return 10 * orig.function(string)
        } else {
            return orig.function(string)
        }
    }
}

final class FunctionHookTests: XCTestCase {

    func testWithoutExplicitImage() {
        XCTAssertEqual(atoi("1234"), 12340)
        XCTAssertEqual(atoi("51"), 51, "Hook should only multiply by 10 for 1234/2345")
        XCTAssertEqual(atoi("2345"), 23450, "Hook should work multiple times")
    }

    // note the gotcha in Hooks.x.swift:AtofHook
    func testWithExplicitImage() {
        XCTAssertEqual(atof("1.5"), 15)
        XCTAssertEqual(atof("11.3"), 11.3)
        XCTAssertEqual(atof("2.5"), 25)
    }

}
