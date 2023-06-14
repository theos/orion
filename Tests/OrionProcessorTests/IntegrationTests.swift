import XCTest
@testable import OrionProcessor

final class IntegrationTests: XCTestCase {
    func testIntegration() async throws {
        try XCTSkipIf(true)
        // NOTE: If this test is failing, it might indicate that you need to
        // run the `generate-test-fixtures` target.

        let orionTests = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("../OrionTests")
        let fixture = try String(contentsOf: orionTests.appendingPathComponent("Generated.xc.swift"))

        let parser = OrionBatchParser(inputs: [orionTests])
        let data = try await parser.parse()
        let options = OrionGenerator.Options(emitSourceLocations: false)
        let generator = OrionGenerator(data: data, options: options)
        let source = try generator.generate()

        XCTAssertEqual(source, fixture)
    }
}
