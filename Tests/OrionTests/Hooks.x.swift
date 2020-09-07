// NOTE: Run generate-test-fixtures every time this file is updated, in order
// to keep the glue in sync.

import Foundation
import Orion
import OrionTestSupport

struct HooksTweak: TweakWithBackend {
    let backend = FishhookBackend<InternalBackend>()
}

class AtoiHook: FunctionHook {
    static let target = Function(image: nil, name: "atoi")

    func function(_ string: UnsafePointer<Int8>) -> Int32 {
        if strcmp(string, "1234") == 0 || strcmp(string, "2345") == 0 {
            return 10 * orig { $0.function(string) }
        } else {
            return orig { $0.function(string) }
        }
    }
}

class AtofHook: FunctionHook {
    // When using the internal generator, this unfortunately doesn't actually guarantee that the hooked
    // symbol will be in the provided image. It does guarantee that the image *has* a function with the
    // given name though, but due to two level namespacing fishhook may end up hooking functions by the
    // same name in other images as well
    static let target = Function(image: URL(fileURLWithPath: "/usr/lib/libc.dylib"), name: "atof")

    func function(_ string: UnsafePointer<Int8>) -> Double {
        if strcmp(string, "1.5") == 0 || strcmp(string, "2.5") == 0 {
            return 10 * orig { $0.function(string) }
        } else {
            return orig { $0.function(string) }
        }
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

class BasicSubclass: Subclass<BasicClass> {
    // this ensures that the method is added to the *subclass* and doesn't
    // swizzle the superclass imp. If it did swizzle the original, we'd
    // know because the test for the actual `someTestMethod` would fail
    func someTestMethod() -> String {
        "Subclassed test method"
    }

    final func someNewMethod() -> String {
        "New method"
    }

    func subclassableTestMethod() -> String {
        "Subclassed: \(supr { $0.subclassableTestMethod() })"
    }

    class func subclassableTestMethod1() -> String {
        "Subclassed class: \(supr { $0.subclassableTestMethod1() })"
    }
}

class NamedBasicSubclass: NamedSubclass<NSObject> {
    static let superclassName = "BasicClass"

    func subclassableNamedTestMethod() -> String {
        "Subclassed named: \(supr { $0.subclassableNamedTestMethod() })"
    }

    class func subclassableNamedTestMethod1() -> String {
        "Subclassed named class: \(supr { $0.subclassableNamedTestMethod1() })"
    }
}

class AdditionHook: ClassHook<BasicClass> {
    final func someTestProtocolMethod() -> String {
        "New method"
    }

    final class func someTestProtocolClassMethod() -> String {
        "New class method"
    }
}

class InheritedHook: ClassHook<InheritedClass> {
    class func someTestMethod3() -> String {
        "Hooked test class method: \(supr { $0.someTestMethod3() })"
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
