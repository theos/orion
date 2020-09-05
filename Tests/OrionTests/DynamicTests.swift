import XCTest
import Orion

@objc protocol DateInterface {
    var isInToday: Bool { get }
    func `init`(timeIntervalSince1970: TimeInterval) -> NSDate
}

@objc protocol DateClassInterface {
    func dateWithNaturalLanguageString(_ string: String) -> NSDate
}

@objc class MyObjCClass: NSObject {
    @objc class func sayHi() -> String { "hello" }
}

@objc protocol MyObjCInterface {
    func sayHi() -> String
}

final class DynamicTests: XCTestCase {

    func testMultipleDots() {
        XCTAssertEqual(Dynamic.OrionTests.MyObjCClass.as(interface: MyObjCInterface.self).sayHi(), "hello")
    }

    func testInstanceInterface() {
        XCTAssertFalse(NSDate(timeIntervalSince1970: 0).as(interface: DateInterface.self).isInToday)
        XCTAssertTrue(NSDate().as(interface: DateInterface.self).isInToday)
    }

    func testClassInterface() {
        XCTAssertEqual(
            Calendar.current.startOfDay(for: Date()),
            Dynamic.NSDate.as(interface: DateClassInterface.self).dateWithNaturalLanguageString("today") as Date
        )
    }

    func testAllocInterface() {
        let date = Dynamic.NSDate.alloc(interface: DateInterface.self).`init`(timeIntervalSince1970: 0)
        XCTAssertEqual(date as Date, Date(timeIntervalSince1970: 0))
    }

}
