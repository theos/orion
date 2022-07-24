import XCTest
@testable import OrionProcessor

final class IntegrationTests: XCTestCase {
    func testIntegration() throws {
        try XCTSkipIf(true)
        // NOTE: If this test is failing, it might indicate that you need to
        // run the `generate-test-fixtures` target.

        let orionTests = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("../OrionTests")
        let fixture = try String(contentsOf: orionTests.appendingPathComponent("Generated.xc.swift"))

        let parser = OrionBatchParser(inputs: [orionTests])
        let data = try parser.parse()
        let options = OrionGenerator.Options(emitSourceLocations: false)
        let generator = OrionGenerator(data: data, options: options)
        let source = try generator.generate()

        XCTAssertEqual(source, fixture)
    }

    func testIntegrationPerformance() throws {
        // TODO: create a separate target for performance tests
        try XCTSkipIf(true)
        let orionTests = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("../OrionTests")
        let contents = try String(contentsOf: orionTests.appendingPathComponent("Hooks.x.swift"))
        var _error: Error?
        measure {
            let parser = OrionParser(contents: contents)
            do {
                let data = try parser.parse()
                let generator = OrionGenerator(data: data)
                _ = try generator.generate()
            } catch {
                _error = error
                XCTFail("Parser/generator threw an error")
            }
        }
        if let error = _error { throw error }
    }

    static var allTests = [
        ("testIntegration", testIntegration),
        ("testIntegrationPerformance", testIntegrationPerformance)
    ]
}
