import XCTest
@testable import OrionProcessor

final class ParserTests: XCTestCase {
    func testNoArguments() async throws {
        let contents = #"""
        class LabelHook: ClassHook<UILabel> {
            func `init`() {
                print("hi")
            }
        }
        """#
        let parser = OrionParser(contents: contents, fileName: "unknown")

        let data = try await parser.parse()
        XCTAssertEqual(data.functionHooks.count, 0)
        XCTAssertEqual(data.tweaks.count, 0)
        XCTAssertEqual(data.classHooks.count, 1)

        let methods = data.classHooks[0].methods
        XCTAssertEqual(methods.count, 1)

        XCTAssertEqual("\(methods[0].function.identifier)", "`init`")
    }
}
