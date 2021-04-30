import Foundation

private extension RandomAccessCollection {
    func concurrentMap<T>(_ block: (Element) -> T) -> [T] {
        let n = self.count
        guard n != 0 else { return [] }
        let start = startIndex
        return [T](unsafeUninitializedCapacity: n) { buf, count in
            // we use a buffer here so that in each parallel "iteration"
            // we can write to the idx'th address locklessly. If we'd
            // used an array the trivial way we would've had to lock and
            // call append each time.
            let base = buf.baseAddress!
            DispatchQueue.concurrentPerform(iterations: n) { idx in
                (base + idx).initialize(
                    to: block(self[index(start, offsetBy: idx)])
                )
            }
            count = n
        }
    }
}

// parses multiple files/directories with parallelization.
// deterministic input order => deterministic output.
public final class OrionBatchParser {
    private struct ParserError: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) {
            self.description = description
        }
    }

    public let inputs: [URL]
    public let diagnosticEngine: OrionDiagnosticEngine
    public let options: OrionParser.Options
    // Note: inputs can include directories
    public init(inputs: [URL], diagnosticEngine: OrionDiagnosticEngine = .init(), options: OrionParser.Options = .init()) {
        self.inputs = inputs
        self.diagnosticEngine = diagnosticEngine
        self.options = options
    }

    private func computeFiles() throws -> [URL] {
        try inputs.flatMap { input -> [URL] in
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: input.path, isDirectory: &isDir) else {
                throw ParserError("File '\(input.path)' does not exist.")
            }
            if isDir.boolValue {
                guard let enumerator = FileManager.default.enumerator(atPath: input.path) else {
                    throw ParserError("Could not enumerate directory '\(input.path)'.")
                }
                return enumerator.compactMap { file -> URL? in
                    // swiftlint:disable:next force_cast
                    let path = file as! String
                    let url = input.appendingPathComponent(path)
                    guard url.pathExtension == "swift" else { return nil }
                    return url
                }
            } else {
                return [input]
            }
        }
    }

    public func parse() throws -> OrionData {
        // Pre-compute the list of files so that we can concurrentMap, which
        // requires GCD to know how many parallel "iterations" it has to perform.
        // This takes a negligible amount of time and it's just filenames so it's
        // not much memory either. Also, we can sort the files to ensure
        // determinism.
        let files = try computeFiles().sorted { $0.path < $1.path }
        let engine = diagnosticEngine
        let allData = files.concurrentMap { file -> Result<OrionData, Error> in
            Result { try OrionParser(file: file, diagnosticEngine: engine, options: options).parse() }
        }
        return OrionData(merging: try allData.map { try $0.get() })
    }
}
