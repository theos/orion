import Foundation
import OrionC

public struct FishhookBackend<UnderlyingBackend: Backend>: Backend {
    let underlyingBackend: UnderlyingBackend

    public init(underlyingBackend: UnderlyingBackend) {
        self.underlyingBackend = underlyingBackend
    }

    public struct Builder: HookBuilder {
        fileprivate struct Request {
            let symbol: String
            let replacement: UnsafeMutableRawPointer
            let image: URL?
            let completion: (UnsafeMutableRawPointer?) -> Void
        }

        var underlyingBuilder: UnderlyingBackend.Builder
        fileprivate var requests: [Request] = []
    }

    private func apply(requests: [Builder.Request]) {
        guard !requests.isEmpty else { return }

        // we need to keep this around, so we don't deallocate it. See comment in rebinding.init call
        // for rationale.
        let origs = UnsafeMutableBufferPointer<UnsafeMutableRawPointer?>.allocate(capacity: requests.count)

        // NOTE: Unfortunately fishhook doesn't support specifying a symbol's image (although
        // there's a fork that does; maybe we should consider using it?). While it may seem like
        // rebind_symbols_image does this job, its purpose is in fact to only make the hook apply
        // to callers in that image, and not to specify the image of the target symbol itself.

        var rebindings = requests.enumerated().map { idx, request in
            rebinding(
                // Turns out fishhook doesn't copy this string so we're responsible for keeping
                // it alive, because the rebindings are stored globally, and are accessed not
                // only when rebind_symbols is called but also every time a new image is added.
                // While we could use a dict to keep a single copy of each symbol alive, blindly
                // calling strdup is alright since each hooked symbol is most likely unique anyway.
                name: strdup(request.symbol),
                replacement: request.replacement,
                // this is also stored globally, as mentioned above. It appears that fishhook writes
                // to this each time an image is processed, passing in that image's orig stub. Even
                // though this orig is later discarded, we can't pass NULL because we do check it in
                // order to know whether hooking was successful
                replaced: origs.baseAddress! + idx
            )
        }

        guard orion_rebind_symbols(&rebindings, rebindings.count) == 0
            else { fatalError("Failed to hook functions") }

        zip(requests, origs).forEach { $0.completion($1) }
    }

    public func hook(_ build: (inout Builder) -> Void) {
        underlyingBackend.hook {
            var builder = Builder(underlyingBuilder: $0)
            build(&builder)
            apply(requests: builder.requests)
            $0 = builder.underlyingBuilder
        }
    }
}

extension FishhookBackend.Builder {

    public mutating func addFunctionHook(
        _ function: Function,
        replacement: UnsafeMutableRawPointer,
        completion: @escaping (UnsafeMutableRawPointer) -> Void
    ) {
        guard case .symbol(let image, let symbol) = function.descriptor else {
            fatalError("""
            The fishhook backend cannot hook functions at raw addresses. If possible, provide \
            a symbol name and image instead.
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

        let request = Request(
            symbol: symbol,
            replacement: replacement,
            image: image
        ) { brokenOrig in
            guard brokenOrig != nil else { fatalError("Failed to hook function \(function)") }
            completion(orig)
        }
        requests.append(request)
    }

    public mutating func addMethodHook(
        cls: AnyClass,
        sel: Selector,
        replacement: UnsafeMutableRawPointer,
        completion: @escaping (UnsafeMutableRawPointer) -> Void
    ) {
        underlyingBuilder.addMethodHook(cls: cls, sel: sel, replacement: replacement, completion: completion)
    }

}

extension FishhookBackend: DefaultBackend where UnderlyingBackend: DefaultBackend {
    public init() {
        self.init(underlyingBackend: UnderlyingBackend())
    }
}
