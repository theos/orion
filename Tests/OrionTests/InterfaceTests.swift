import XCTest
import Orion

@objc protocol DateInterface {
    var isInToday: Bool { get }
    func `init`(timeIntervalSince1970: TimeInterval) -> NSDate
}

@objc protocol DateClassInterface {
    func dateWithNaturalLanguageString(_ string: String) -> NSDate
}

final class InterfaceTests: XCTestCase {

    func testInstanceInterface() {
        XCTAssertFalse(NSDate(timeIntervalSince1970: 0).withInterface(DateInterface.self).isInToday)
        XCTAssertTrue(NSDate().withInterface(DateInterface.self).isInToday)
    }

    func testClassInterface() {
        XCTAssertEqual(
            Calendar.current.startOfDay(for: Date()),
            NSDate.withInterface(DateClassInterface.self).dateWithNaturalLanguageString("today") as Date
        )
    }

    func testAllocInterface() {
        let date = NSDate.allocWithInterface(DateInterface.self).`init`(timeIntervalSince1970: 0)
        XCTAssertEqual(date as Date, Date(timeIntervalSince1970: 0))
    }

}
