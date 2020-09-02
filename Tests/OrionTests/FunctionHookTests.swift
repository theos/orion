import XCTest
import Orion
import OrionTestSupport

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
