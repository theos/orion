import Foundation
import OrionC

// https://github.com/apple/swift/blob/cc511c23254f7203e2f818c5e4f3298ce9497c71/stdlib/private/SwiftPrivate/SwiftPrivate.swift#L32
// Compute the prefix sum of `seq`.
private func scan<S: Sequence, U>(_ seq: S, _ initial: U, _ combine: (U, S.Element) -> U) -> [U] {
    var result: [U] = []
    result.reserveCapacity(seq.underestimatedCount)
    var runningResult = initial
    for element in seq {
        runningResult = combine(runningResult, element)
        result.append(runningResult)
    }
    return result
}

// more efficient than mapping with strdup because this creates one large allocation rather than multiple small ones.
// modified to use UInt8 instead of CChar, and also to not include the final NULL element
// https://github.com/apple/swift/blob/cc511c23254f7203e2f818c5e4f3298ce9497c71/stdlib/private/SwiftPrivate/SwiftPrivate.swift#L60
private func withArrayOfCStrings<S: Sequence, R>(
    _ args: S, _ body: ([UnsafeMutablePointer<UInt8>?]) -> R
) -> R where S.Element == String {
    // dropLast removes the extra element at the end which we could otherwise set to NULL
    let argsCounts = args.lazy.dropLast().map { $0.utf8.count + 1 }
    let argsOffsets = [0] + scan(argsCounts, 0, +)
    let argsBufferSize = argsOffsets.last!
    var argsBuffer: [UInt8] = []
    argsBuffer.reserveCapacity(argsBufferSize)
    for arg in args {
        argsBuffer.append(contentsOf: arg.utf8)
        argsBuffer.append(0)
    }
    return argsBuffer.withUnsafeMutableBufferPointer { argsBuffer in
        let ptr = argsBuffer.baseAddress!
        return body(argsOffsets.map { ptr + $0 })
    }
}

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

    private func apply(
        requests: [Builder.Request],
        symbols: [UnsafeMutablePointer<UInt8>?],
        origs: UnsafeMutableBufferPointer<UnsafeMutableRawPointer?>
    ) {
        // NOTE: Unfortunately fishhook doesn't support specifying a symbol's image (although
        // there's a fork that does; maybe we should consider using it?). While it may seem like
        // rebind_symbols_image does this job, its purpose is in fact to only make the hook apply
        // to callers in that image, and not to specify the image of the target symbol itself.

        var rebindings = symbols.enumerated().map { idx, sym in
            rebinding(
                name: UnsafeRawPointer(sym!).assumingMemoryBound(to: Int8.self),
                replacement: requests[idx].replacement,
                replaced: origs.baseAddress! + idx
            )
        }

        guard orion_rebind_symbols(&rebindings, symbols.count) == 0
            else { fatalError("Failed to hook functions") }
    }

    private func apply(requests: [Builder.Request]) {
        if !requests.isEmpty {
            let symbols = requests.lazy.map { $0.symbol }
            var origs: [UnsafeMutableRawPointer?] = Array(repeating: nil, count: requests.count)

            withArrayOfCStrings(symbols) { rawSymbols in
                origs.withUnsafeMutableBufferPointer { rawOrigs in
                    apply(requests: requests, symbols: rawSymbols, origs: rawOrigs)
                }
            }

            requests.enumerated().forEach { $1.completion(origs[$0]) }
        }
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

    public mutating func addFunctionHook<Code>(_ function: Function, replacement: Code, completion: @escaping (Code) -> Void) {
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
            replacement: unsafeBitCast(replacement, to: UnsafeMutableRawPointer.self),
            image: image
        ) { brokenOrig in
            guard brokenOrig != nil else { fatalError("Failed to hook function \(function)") }
            completion(unsafeBitCast(orig, to: Code.self))
        }
        requests.append(request)
    }

    public mutating func addMethodHook<Code>(cls: AnyClass, sel: Selector, replacement: Code, completion: @escaping (Code) -> Void) {
        underlyingBuilder.addMethodHook(cls: cls, sel: sel, replacement: replacement, completion: completion)
    }

}

extension FishhookBackend: DefaultBackend where UnderlyingBackend: DefaultBackend {
    public init() {
        self.init(underlyingBackend: UnderlyingBackend())
    }
}
