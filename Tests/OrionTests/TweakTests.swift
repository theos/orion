import XCTest
@testable import Orion
import OrionTestSupport
import OrionBackend_Fishhook

struct HooksTweak: TweakWithBackend {
    static let backend = Backends.Fishhook<Backends.Internal>()

    static var errors: [OrionHookError] = []
    static func handleError(_ error: OrionHookError) {
        errors.append(error)
    }

    init() {
        InitGroup(x: 27).activate()
    }

    func tweakDidActivate() {
        print("Activated!")
    }
}

struct InitGroup: HookGroup {
    let x: Int
}
class InitGroupHook: ClassHook<BasicClass> {
    typealias Group = InitGroup
    static var activatedX: Int?
    static func hookDidActivate() {
        activatedX = group.x
    }
}

class BadHook: ClassHook<NSObject> {
    static let targetName = "BadClass"
}

class BadMethodHook: ClassHook<BasicClass> {
    func badMethod() { orig.badMethod() }

    // orion:new
    func someTestMethod() -> String { orig.someTestMethod() }
}

class BadFunctionHook: FunctionHook {
    static let target = Function.symbol("nonExistentSymbol", image: nil)
    func function() {}
}

final class TweakTests: XCTestCase {
    func testInitGroupActivation() {
        XCTAssertEqual(
            InitGroupHook.activatedX, 27,
            "It should be possible to activate groups in Tweak.init"
        )
    }

    func testHookingErrorCount() {
        XCTAssertEqual(HooksTweak.errors.count, 4, "Unexpected number of hooking errors")
    }

    func testBadTargetError() {
        XCTAssert(HooksTweak.errors.contains {
            switch $0 {
            case .targetClassNotAvailable("\(BadHook.self)", ClassHookError.targetNotFound):
                return true
            default:
                return false
            }
        }, "Expected BadHook targetNotFound error to occur")
    }

    func testBadMethodError() {
        XCTAssert(HooksTweak.errors.contains {
            switch $0 {
            case .methodHookFailed(let cls, #selector(BadMethodHook.badMethod), false, _)
                    where cls == BasicClass.self:
                return true
            default:
                return false
            }
        }, "Expected BasicHook badMethod hook failure error to occur")
    }

    func testNonExistentFunctionError() {
        XCTAssert(HooksTweak.errors.contains {
            switch $0 {
            case .functionHookFailed(.symbol("nonExistentSymbol", image: nil), _):
                return true
            default:
                return false
            }
        }, "Expected functionHookFailed error to occur")
    }

    func testAdditionError() {
        // `someTestMethod` already exists on BasicClass so orion:new should fail
        XCTAssert(HooksTweak.errors.contains {
            switch $0 {
            case .methodAdditionFailed(let cls, #selector(BadMethodHook.someTestMethod), false, _)
                    where cls == BasicClass.self:
                return true
            default:
                return false
            }
        }, "Expected methodAdditionFailed error to occur")
    }
}
