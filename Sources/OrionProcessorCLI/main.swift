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

let allData: [OrionData]
let backend: OrionGenerator.Backend

let isTesting = false
if isTesting {
    let contents = #"""
    import Orion
    import Foundation

    class MyFunctionHook: FunctionHook {
        static let target = Function(image: nil, name: "socket")

        func function(foo: Int32, bar: Int32) -> Int32 {
            typealias Foo = @convention(c) () -> Void
            _ = orig { function(foo: foo, bar: bar) }
            return 1
        }
    }

    class MyHook: NamedClassHook<NSObject> {
        static let targetName = "NSDateFormatter"

        func string(fromDate date: Date) -> String {
            let actual = orig { string(fromDate: date) }
            return "Swizzled: '\(actual)'"
        }

        @objc(localizedStringFromDate:dateStyle:timeStyle:)
        class func localizedString(
            from date: Date, dateStyle dstyle: DateFormatter.Style, timeStyle tstyle: DateFormatter.Style
        ) -> String {
            "Class method: \(orig { localizedString(from: date, dateStyle: dstyle, timeStyle: tstyle) })"
        }
    }
    """#

//    let contents = #"""
//    class MyHook: ClassHook<UILabel> {
//        func `init`() {}
//        func `init`(foo: String) {}
//    }
//    """#

    let parser = OrionParser(contents: contents)
    allData = try catchingOrionFailures { [try parser.parse()] }
    backend = .internal
} else {
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
    guard let _backend = backends[backendKey] else { usage() }
    backend = _backend

    let files = args.map(URL.init(fileURLWithPath:))
    allData = try files.map { file -> OrionData in
        let parser = OrionParser(file: file, diagnosticEngine: engine)
        return try catchingOrionFailures { try parser.parse() }
    }
}

let merged = OrionData(merging: allData)
let generator = OrionGenerator(data: merged, diagnosticEngine: engine)
let companion = try catchingOrionFailures {
    try generator.generate(backend: backend)
}

print(companion)
