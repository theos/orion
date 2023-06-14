import Foundation

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

    public func parse() async throws -> OrionData {
        // Pre-compute the list of files so that we can concurrentMap, which
        // requires GCD to know how many parallel "iterations" it has to perform.
        // This takes a negligible amount of time and it's just filenames so it's
        // not much memory either. Also, we can sort the files to ensure
        // determinism.
        let files = try computeFiles().sorted { $0.path < $1.path }
        let engine = diagnosticEngine
        // we don't use a throwing task group since that terminates as soon as
        // an error occurs; we want to collect diagnostics across files.
        let allData = await withTaskGroup(of: Result<OrionData, Error>.self) { group in
            for file in files {
                group.addTask {
                    do {
                        let parser = try await OrionParser(file: file, diagnosticEngine: engine, options: self.options)
                        return try await .success(parser.parse())
                    } catch {
                        return .failure(error)
                    }
                }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }
        return OrionData(merging: try allData.map { try $0.get() })
    }
}
