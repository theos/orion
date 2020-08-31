import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(IntegrationTests.allTests),
        testCase(GeneratorTests.allTests),
        testCase(ParserTests.allTests),
    ]
}
#endif
