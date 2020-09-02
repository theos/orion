import Foundation
import OrionC
import MachO // required to use dyld funcs on iOS

public struct InternalBackend: DefaultBackend {
    // TODO: Maybe move the fishhook stuff into a separate backend, in a separate module
    public func hookFunction<Code>(_ function: Function, replacement: Code) -> Code {
        guard case .symbol(let image, let symbol) = function.descriptor else {
            fatalError("""
            Cannot hook function at address \(function). If possible, provide a symbol \
            name and image instead.
            """)
        }

        // NOTE: We don't use the orig that fishhook returns because calling that seems to rebind
        // the dyld symbol stub, which means our hook only works up until it decides to call orig
        // after which all future calls are broken.
        // See: https://github.com/facebook/fishhook/issues/36

        let handle: UnsafeMutableRawPointer
        if let image = image {
            guard let _handle = image.withUnsafeFileSystemRepresentation({ dlopen($0, RTLD_NOLOAD | RTLD_NOW) })
                else { fatalError("Image not loaded: \(image.path)") }
            handle = _handle
        } else {
            handle = UnsafeMutableRawPointer(bitPattern: -2)! // RTLD_DEFAULT
        }

        guard let orig = dlsym(handle, symbol)
            else { fatalError("Could not find symbol \(symbol)\(image.map { " in image \($0.path)" } ?? "")") }

        var brokenOrig: UnsafeMutableRawPointer?

        symbol.withCString { symbolRaw in
            withUnsafeMutablePointer(to: &brokenOrig) { origRaw in
                var rebindings: [rebinding] = [
                    rebinding(
                        name: symbolRaw,
                        replacement: unsafeBitCast(replacement, to: UnsafeMutableRawPointer.self),
                        replaced: origRaw
                    )
                ]

                // NOTE: Unfortunately fishhook doesn't support specifying a symbol's image (although
                // there's a fork that does; maybe we should consider using it?). While it may seem like
                // rebind_symbols_image does this job, its purpose is in fact to only make the hook apply
                // to callers in that image, and not to specify the image of the target symbol itself.
                // I found this out the hard way.

                guard orion_rebind_symbols(&rebindings, 1) == 0
                    else { fatalError("Failed to hook function \(function)") }
            }
        }

        guard brokenOrig != nil else { fatalError("Failed to hook function \(function)") }
        return unsafeBitCast(orig, to: Code.self)
    }

    public func hookMethod<Code>(cls: AnyClass, sel: Selector, replacement: Code) -> Code {
        guard let method = class_getInstanceMethod(cls, sel) else {
            let isMeta = class_isMetaClass(cls)
            let methodDescription = "\(isMeta ? "+" : "-")[\(cls) \(sel)]"
            fatalError("Could not find method \(methodDescription)")
        }
        return unsafeBitCast(
            method_setImplementation(method, unsafeBitCast(replacement, to: IMP.self)),
            to: Code.self
        )
    }

    public init() {}
}

