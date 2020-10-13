import Foundation
import OrionProcessor

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

func usage() -> Never {
    let string = """
    Usage: \(CommandLine.arguments[0]) [<module>.]<backend> <file1.swift...>
    """
    fputs("\(string)\n", stderr)
    exit(EX_USAGE)
}

var args = CommandLine.arguments.dropFirst()
guard args.count >= 2 else { usage() }

let backendName = args.removeFirst() // shift
guard let backend = OrionGenerator.Backend(name: backendName)
    else { usage() }

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
