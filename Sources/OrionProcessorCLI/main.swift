import Foundation
import OrionProcessor

extension OrionGenerator.Backend {
    static let substrate: Self = .init(name: "SubstrateBackend", module: "SubstrateOrionBackend")

    static let all: [String: Self] = [
        "internal": .internal,
        "MobileSubstrate": .substrate
    ]
}

func catchingOrionFailures<Result>(block: () throws -> Result) throws -> Result {
    do {
        return try block()
    } catch {
        if error is OrionFailure {
            // exit gracefully; OrionFailure means we've already emitted
            // an error message
            exit(1)
        } else {
            throw error
        }
    }
}

let engine = OrionDiagnosticEngine()
engine.addConsumer(.printing)

let backends = OrionGenerator.Backend.all

func usage() -> Never {
    let string = """
    Usage: \(CommandLine.arguments[0]) <backend> <file1.swift...>
    - backends: \(backends.keys.sorted().joined(separator: ", "))
    """
    fputs("\(string)\n", stderr)
    exit(EX_USAGE)
}

var args = CommandLine.arguments.dropFirst()
guard args.count >= 2 else { usage() }

let backendKey = args.removeFirst() // shift
guard let backend = backends[backendKey] else { usage() }

let files = args.map(URL.init(fileURLWithPath:))
let allData = try files.map { file -> OrionData in
    let parser = OrionParser(file: file, diagnosticEngine: engine)
    return try catchingOrionFailures { try parser.parse() }
}

let merged = OrionData(merging: allData)
let generator = OrionGenerator(data: merged, diagnosticEngine: engine)
let glue = try catchingOrionFailures {
    try generator.generate(backend: backend)
}

// the glue already includes a trailing newline so don't add a second one
print(glue, terminator: "")
