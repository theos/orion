import Foundation

// A Subclass is effectively just a ClassHook where we've added a new class pair on top
// of the original target
open class Subclass<Target: AnyObject>: ClassHook<Target> {
    open class var className: String { "OrionSubclass.\(NSStringFromClass(self))" }

    open class var superclass: Target.Type { Target.self }

    open override class func computeTarget() -> Target.Type {
        print(className)
        guard let pair: AnyClass = objc_allocateClassPair(superclass, className, 0)
            else { fatalError("Could not allocate subclass for \(self)") }
        objc_registerClassPair(pair)
        guard let converted = pair as? Target.Type
            else { fatalError("Allocated invalid subclass for \(self)") }
        return converted
    }
}

public protocol _NamedSubclassProtocol {
    static var superclassName: String { get }
}

open class _NamedSubclassClass<Target: AnyObject>: Subclass<Target> {
    open override class var superclass: Target.Type {
        guard let superclassName = (self as? _NamedSubclassProtocol.Type)?.superclassName
            else { fatalError("Use NamedSubclass") }
        return Dynamic(superclassName).as(type: Target.self)
    }
}

public typealias NamedSubclass<Target: AnyObject> = _NamedSubclassClass<Target> & _NamedSubclassProtocol
