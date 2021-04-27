import Foundation
@_implementationOnly import CydiaSubstrate
#if SWIFT_PACKAGE
import Orion
#endif

extension Backends {

    /// A backend which utilizes CydiaSubstrate APIs for hooking.
    ///
    /// This backend can hook most functions and methods. Therefore
    /// if the target system has CydiaSubstrate – or another hooking
    /// framework which vends its API – installed, this backend makes
    /// for a sensible default choice.
    ///
    /// - Warning: Do not use this backend if the target system does not
    /// have a framework which vends the CydiaSubstrate APIs. Doing so
    /// will result in the process crashing with an "undefined symbols"
    /// error.
    public struct Substrate: DefaultBackend {
        public init() {}
    }

}

extension Backends.Substrate {

    private struct HookingError: LocalizedError, CustomStringConvertible {
        let description: String
        var errorDescription: String? { description }
        init(_ description: String) {
            self.description = description
        }
    }

    private struct ImageFetcher {
        var cache: [URL: MSImageRef?] = [:]

        mutating func image(at url: URL) -> MSImageRef? {
            if let image = cache[url] { return image }
            let image = url.withUnsafeFileSystemRepresentation(MSGetImageByName)
            cache[url] = image
            return image
        }
    }

    private func address(
        for function: Function,
        fetcher: inout ImageFetcher
    ) -> UnsafeMutableRawPointer? {
        switch function {
        case .address(let address): return address
        case .symbol(let name, nil):
            return MSFindSymbol(nil, name)
        case .symbol(let name, let imageURL?):
            return fetcher.image(at: imageURL)
                .flatMap { MSFindSymbol($0, name) }
        }
    }

    public func apply(descriptors: [HookDescriptor]) {
        var imageFetcher = ImageFetcher()
        descriptors.forEach {
            switch $0 {
            case let .function(function, replacement, completion):
                guard let symbol = address(for: function, fetcher: &imageFetcher) else {
                    return completion(.failure(HookingError("Could not find function")))
                }
                var old: UnsafeMutableRawPointer?
                MSHookFunction(symbol, replacement, &old)
                guard let unwrapped = old else {
                    return completion(.failure(HookingError("Could not hook function")))
                }
                completion(.success(unwrapped))
            case let .method(cls, sel, replacement, completion):
                var old: IMP?
                MSHookMessageEx(cls, sel, IMP(replacement), &old)
                guard let unwrapped = old else {
                    return completion(.failure(HookingError("Could not hook method")))
                }
                completion(.success(.init(unwrapped)))
            }
        }
    }

}
