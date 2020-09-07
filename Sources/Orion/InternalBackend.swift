import Foundation

public struct InternalBackend: DefaultBackend {
    public init() {}

    public struct Builder: HookBuilder {
        fileprivate var actions: [() -> Void] = []

        public func addFunctionHook(
            _ function: Function,
            replacement: UnsafeMutableRawPointer,
            completion: (UnsafeMutableRawPointer) -> Void
        ) {
            fatalError("The internal backend does not support function hooking")
        }

        public mutating func addMethodHook(
            cls: AnyClass,
            sel: Selector,
            replacement: UnsafeMutableRawPointer,
            completion: @escaping (UnsafeMutableRawPointer) -> Void
        ) {
            let methodDescription = { "\(class_isMetaClass(cls) ? "+" : "-")[\(cls) \(sel)]" }

            guard let origMethod = class_getInstanceMethod(cls, sel) else {
                fatalError("Could not find method \(methodDescription())")
            }

            guard let types = method_getTypeEncoding(origMethod) else {
                fatalError("Could not get type encoding for method \(methodDescription())")
            }

            actions.append {
                let imp = IMP(replacement)
                let orig: IMP
                // first try to add the method (in case the current imp is inherited)
                if class_addMethod(cls, sel, imp, types) {
                    // if added, return the super imp
                    orig = method_getImplementation(origMethod)
                } else {
                    // otherwise, the current class has its own imp of the method. Replace it.
                    orig = method_setImplementation(origMethod, imp)
                }
                completion(.init(orig))
            }
        }
    }

    public func hook(_ build: (inout Builder) -> Void) {
        var builder = Builder()
        build(&builder)
        builder.actions.forEach { $0() }
    }
}
