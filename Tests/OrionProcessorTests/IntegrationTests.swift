import XCTest
@testable import OrionProcessor

final class IntegrationTests: XCTestCase {
    func testIntegration() throws {
        let orionTests = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("../OrionTests")
        let contents = try String(contentsOf: orionTests.appendingPathComponent("Hooks.x.swift"))
        let fixture = try String(contentsOf: orionTests.appendingPathComponent("Generated.xc.swift"))

        let parser = OrionParser(contents: contents)
        let data = try parser.parse()
        let generator = OrionGenerator(data: data)
        let source = try generator.generate()

        XCTAssertEqual(source, fixture)
    }

    static var allTests = [
        ("testIntegration", testIntegration),
    ]
}
