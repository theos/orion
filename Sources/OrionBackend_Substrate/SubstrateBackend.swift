import Foundation
#if SWIFT_PACKAGE
import CSubstrate
import Orion
#endif

extension Backends {
    public struct Substrate: Backend {
        public init() {}
    }
}

extension Backends.Substrate {
    public struct Builder: HookBuilder {
        fileprivate var actions: [() -> Void] = []

        // we can't maintain a single global cache because loaded images can change over
        // time, but it's okay to maintain a cache over a single build operation assuming
        // there aren't any images that are being [un]loaded in parallel
        private var cache: [URL: MSImageRef?] = [:]

        private mutating func image(at url: URL) -> MSImageRef? {
            if let image = cache[url] { return image }
            let image = url.withUnsafeFileSystemRepresentation(MSGetImageByName)
            cache[url] = image
            return image
        }

        private mutating func address(for function: Function) -> UnsafeMutableRawPointer? {
            switch function {
            case .address(let address): return address
            case .symbol(let name, nil):
                return MSFindSymbol(nil, name)
            case .symbol(let name, let imageURL?):
                return self.image(at: imageURL)
                    .flatMap { MSFindSymbol($0, name) }
            }
        }

        public mutating func addFunctionHook(
            _ function: Function,
            replacement: UnsafeMutableRawPointer,
            completion: @escaping (UnsafeMutableRawPointer) -> Void
        ) {
            guard let symbol = self.address(for: function) else {
                fatalError("The function \(function) could not be found")
            }
            actions.append {
                var old: UnsafeMutableRawPointer?
                MSHookFunction(symbol, replacement, &old)
                guard let unwrapped = old
                    else { fatalError("Could not hook function: \(function)") }
                completion(unwrapped)
            }
        }

        public mutating func addMethodHook(
            cls: AnyClass,
            sel: Selector,
            replacement: UnsafeMutableRawPointer,
            completion: @escaping (UnsafeMutableRawPointer) -> Void
        ) {
            actions.append {
                var old: IMP?
                MSHookMessageEx(cls, sel, IMP(replacement), &old)
                guard let unwrapped = old
                    else { fatalError("Could not hook method: \(cls).\(sel)") }
                completion(.init(unwrapped))
            }
        }
    }

    public func hook(_ build: (inout Builder) -> Void) {
        var builder = Builder()
        build(&builder)
        builder.actions.forEach { $0() }
    }
}
