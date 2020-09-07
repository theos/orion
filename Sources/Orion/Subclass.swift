import Foundation

public protocol NamedSubclass: class, _AnyHook {
    static var superclassName: String { get }
}

// A Subclass is effectively just a ClassHook where we've added a new class pair on top
// of the original target
open class Subclass<Target: AnyObject>: ClassHook<Target> {
    open class var className: String { "OrionSubclass.\(NSStringFromClass(self))" }

    open class var superclass: Target.Type {
        (self as? NamedSubclass.Type).map { Dynamic($0.superclassName).as(type: Target.self) }
            ?? Target.self
    }

    open override class func initializeTargetType() -> Target.Type {
        guard let pair: AnyClass = objc_allocateClassPair(superclass, className, 0)
            else { fatalError("Could not allocate subclass for \(self)") }
        objc_registerClassPair(pair)
        guard let converted = pair as? Target.Type
            else { fatalError("Allocated invalid subclass for \(self)") }
        return converted
    }
}
