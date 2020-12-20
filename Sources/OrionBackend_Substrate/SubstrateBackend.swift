import Foundation
#if SWIFT_PACKAGE
import Substrate
import Orion
#endif

extension Backends {

    /// A backend which utilizes CydiaSubstrate APIs for hooking.
    ///
    /// This backend can hook most functions and methods. Therefore
    /// if the target system has CydiaSubstrate – or another hooking
    /// framework which vends its API – installed, this backend makes
    /// for a sensible default choice.
    public struct Substrate: DefaultBackend {
        public init() {}
    }

}

extension Backends.Substrate {
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

    public func apply(hooks: [HookDescriptor]) {
        var imageFetcher = ImageFetcher()
        hooks.forEach {
            switch $0 {
            case let .function(function, replacement, completion):
                guard let symbol = address(for: function, fetcher: &imageFetcher) else {
                    fatalError("The function \(function) could not be found")
                }
                var old: UnsafeMutableRawPointer?
                MSHookFunction(symbol, replacement, &old)
                guard let unwrapped = old
                    else { fatalError("Could not hook function: \(function)") }
                completion(unwrapped)
            case let .method(cls, sel, replacement, completion):
                var old: IMP?
                MSHookMessageEx(cls, sel, IMP(replacement), &old)
                guard let unwrapped = old else {
                    let method = "\(class_isMetaClass(cls) ? "+" : "-")[\(cls) \(sel)]"
                    fatalError("Could not hook method \(method)")
                }
                completion(.init(unwrapped))
            }
        }
    }
}
