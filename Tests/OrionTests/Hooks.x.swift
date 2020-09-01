// NOTE: Run generate-test-fixtures every time this file is updated, in order
// to keep the glue in sync.

import Foundation
import Orion
import OrionTestSupport

class MyFunctionHook: FunctionHook {
    static let target = Function(image: nil, name: "socket")

    func function(foo: Int32, bar: Int32) -> Int32 {
        _ = orig { $0.function(foo: foo, bar: bar) }
        return 1
    }
}

class BasicHook: ClassHook<BasicClass> {
    func someTestMethod() -> String {
        "Hooked test method"
    }

    func someTestMethod(withArgument argument: Int32) -> String {
        "Hooked: \(orig { $0.someTestMethod(withArgument: argument + 1) })"
    }

    class func someTestMethod2(withArgument argument: Int32) -> String {
        "Hooked class method: \(orig { $0.someTestMethod2(withArgument: argument + 1) })"
    }
}

class NamedBasicHook: NamedClassHook<BasicClass> {
    static let targetName = "BasicClass"

    func methodForNamedTest() -> Bool { true }

    class func classMethodForNamedTest(withArgument arg: String) -> [String] {
        let origVal = orig { $0.classMethodForNamedTest(withArgument: "\(arg), or is it") }
        return ["Hooked named class method"] + origVal
    }
}

class InitHook: ClassHook<InitClass> {
    // just a placeholder to allow forwarding
    func `init`() -> Target { orig { $0.`init`() } }

    func `init`(withX x: Int32) -> Target {
        let this = supr { $0.`init`() }
        Ivars(this)._x = x + 1
        return this
    }
}

class SuperHook: ClassHook<MyClass> {
    @Property(.nonatomic) var x = 11

    func description() -> String {
        "hax description: \(supr { $0.description() })"
    }

    func hooked() -> String {
        if x == 0 {
            return "zero"
        } else {
            x -= 1
            return orig {
                "orig: \($0.hooked()). hax hooked \(supr { $0.description() }). x=\(x), prev=\(hooked())"
            }
        }
    }
}

class PropertyHookX: ClassHook<PropertyClass> {
    @Property(.nonatomic) var x = 1

    func getXValue() -> Int { x }
    func setXValue(_ x: Int) { self.x = x }
}

class PropertyHookY: ClassHook<PropertyClass> {
    @Property(.nonatomic) var x = 1

    func getYValue() -> Int { x }

    func setYValue(_ x: Int) {
        self.x = x
    }
}

class PropertyHook2: ClassHook<PropertyClass2> {
    @Property(.nonatomic) var x = 1

    func getXValue() -> Int { x }

    func setXValue(_ x: Int) {
        self.x = x
    }
}
