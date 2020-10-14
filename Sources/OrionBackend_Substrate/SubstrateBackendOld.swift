/*
import Foundation
import SubstrateSwift
import Orion

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
        private var cache: [URL: Substrate.Image?] = [:]

        private mutating func image(at url: URL) -> Substrate.Image? {
            if let image = cache[url] { return image }
            let image = Substrate.Image(url: url)
            cache[url] = image
            return image
        }

        private mutating func symbol(for function: Function) -> Substrate.Symbol? {
            switch function {
            case .address(let address): return Substrate.Symbol(address: address)
            case .symbol(let name, nil):
                return Substrate.Symbol(image: .all, name: name)
            case .symbol(let name, let imageURL?):
                return self.image(at: imageURL)
                    .flatMap { Substrate.Symbol(image: $0, name: name) }
            }
        }

        public mutating func addFunctionHook(
            _ function: Function,
            replacement: UnsafeMutableRawPointer,
            completion: @escaping (UnsafeMutableRawPointer) -> Void
        ) {
            guard let symbol = self.symbol(for: function) else {
                fatalError("The function \(function) could not be found")
            }
            actions.append {
                completion(symbol.hook(replacement: replacement))
            }
        }

        public mutating func addMethodHook(
            cls: AnyClass,
            sel: Selector,
            replacement: UnsafeMutableRawPointer,
            completion: @escaping (UnsafeMutableRawPointer) -> Void
        ) {
            let method = Substrate.Method(class: cls, selector: sel)
            actions.append {
                completion(method.hook(replacement: replacement))
            }
        }
    }

    public func hook(_ build: (inout Builder) -> Void) {
        var builder = Builder()
        build(&builder)
        builder.actions.forEach { $0() }
    }
}
*/
