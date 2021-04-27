import Foundation

/// Internal storage associated with a `FunctionHook`. Do not use this yourself.
///
/// :nodoc:
public final class _GlueFunctionHookStorage {
    @LazyAtomic private(set) var group: HookGroup

    init(loadGroup: @escaping () -> HookGroup) {
        _group = LazyAtomic(wrappedValue: loadGroup())
    }
}

/// A placeholder function hook glue type. Do not use this yourself.
///
/// This type is the default value for the `FunctionHookProtocol._Glue` constraint,
/// used to satisfy the compiler until the actual glue is provided.
///
/// :nodoc:
public enum _GlueFunctionHookPlaceholder: _GlueFunctionHook {
    public final class HookType: FunctionHook {
        public static var target: Function { error() }
    }
    public typealias OrigType = HookType

    public static var origFunction: Void {
        get { error() }
        // swiftlint:disable:next unused_setter_value
        set { error() }
    }

    public static var storage: _GlueFunctionHookStorage { error() }
    public static func activate(withClassHookBuilder builder: inout _GlueClassHookBuilder) { error() }

    private static func error() -> Never {
        orionError("Placeholder function hook used. Has the glue file been compiled?")
    }
}

/// A marker protocol to which `_GlueClassHook`'s orig/supr trampolines conform. Do
/// not use this yourself.
///
/// :nodoc:
public protocol _GlueFunctionHookTrampoline: FunctionHookProtocol {}

/// A concrete function hook, implemented in the glue file. Do not use
/// this directly.
///
/// :nodoc:
public protocol _GlueFunctionHook: _GlueAnyHook {
    associatedtype HookType: FunctionHookProtocol
    associatedtype OrigType: FunctionHookProtocol
    associatedtype Code

    static var storage: _GlueFunctionHookStorage { get }
    static var origFunction: Code { get set }
}

/// :nodoc:
extension _GlueFunctionHook {
    public static func activate(in tweak: Tweak.Type) -> [HookDescriptor] {
        [.function(function: HookType.target, replacement: unsafeBitCast(origFunction, to: UnsafeMutableRawPointer.self)) {
            switch $0 {
            case .success(let code):
                origFunction = unsafeBitCast(code, to: Code.self)
            case .failure(let error):
                tweak.handleError(
                    OrionHookError.functionHookFailed(target: HookType.target, underlying: error)
                )
            }
        }]
    }

    public static var groupType: HookGroup.Type {
        HookType.Group.self
    }

    public static func hookWillActivate() -> Bool {
        HookType.hookWillActivate()
    }

    public static func hookDidActivate() {
        HookType.hookDidActivate()
    }

    public static func initializeStorage() -> _GlueFunctionHookStorage {
        _GlueFunctionHookStorage(loadGroup: HookType.loadGroup)
    }
}
