import Foundation
import OrionProcessor
import ArgumentParser

extension OrionGenerator.Backend: ExpressibleByArgument {
    public init?(argument: String) {
        self.init(name: argument)
    }
    public var defaultValueDescription: String { name }
}

struct OrionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "OrionCLI",
        abstract: "The Orion preprocessor."
    )

    @Option(
        name: [.short, .long],
        help: ArgumentHelp(
            "Path to the output file.",
            discussion: "Defaults to stdout.",
            valueName: "file"
        ),
        completion: .file()
    ) var output: String?

    @Option(
        name: [.short, .long],
        help: ArgumentHelp(
            "Specify the backend to use.",
            discussion: """
            Orion uses the provided backend to perform the actual hooking of functions \
            and methods.
            The Internal backend, along with potentially Substrate and/or Fishhook \
            (depending on the distribution of Orion), are built-in. It is also possible \
            to use a custom backend; consult the documentation for the `Backend` protocol \
            for more information.
            """
        )
    ) var backend: OrionGenerator.Backend = .internal

    @Option(
        name: .customLong("backend-module"),
        help: ArgumentHelp(
            "Import extra backend module.",
            discussion: """
            Any provided module(s) will be imported into the glue file. May be used if \
            a custom backend module name does not conform to the standard format, or if \
            it requires additional modules to be imported.
            """,
            valueName: "module"
        )
    ) var backendModules: [String] = []

    @Option(
        help: ArgumentHelp(
            "Add name to schema.",
            discussion: """
            The schema list can be used to conditionally enable Orion directives. It is \
            empty by default. Read the documentation on directives for more information.
            """,
            valueName: "name"
        )
    ) var schema: [String] = []

    @Flag(
        inversion: .prefixedNo,
        help: ArgumentHelp(
            "Emit source locations.",
            discussion: """
            Creates a source map from locations in the glue file to locations in your code. \
            Allows for better compiler diagnostics, but may increase compilation time and glue \
            file size. There is no impact on the compiled binary.
            """
        )
    )
    var sourceLocations: Bool = true

    @Argument(
        help: ArgumentHelp(
            "Directories/source files to process.",
            discussion: """
            There must be at least one file or directory provided. Directories \
            will be searched recursively for .swift source files to process.

            Use a single dash ("-") to read from stdin.
            """,
            valueName: "input"
        ),
        completion: .file()
    )
    var inputs: [String]

    private func _run() throws {
        let engine = OrionDiagnosticEngine()
        engine.addConsumer(.printing)

        let parserOptions = OrionParser.Options(schema: Set(schema))

        let data: OrionData
        if inputs == ["-"] {
            var input = ""
            // read stdin until EOF
            while let line = readLine(strippingNewline: false) {
                input.append(line)
            }
            let parser = OrionParser(
                contents: input,
                diagnosticEngine: engine,
                options: parserOptions
            )
            data = try parser.parse()
        } else {
            let parser = OrionBatchParser(
                inputs: inputs.map(URL.init(fileURLWithPath:)),
                diagnosticEngine: engine,
                options: parserOptions
            )
            data = try parser.parse()
        }

        let generatorOptions = OrionGenerator.Options(
            backend: backend,
            extraBackendModules: Set(backendModules),
            emitSourceLocations: sourceLocations
        )
        let generator = OrionGenerator(data: data, diagnosticEngine: engine, options: generatorOptions)
        let out = try generator.generate()
        if let output = output {
            let outputURL = URL(fileURLWithPath: output)
            try out.write(to: outputURL, atomically: true, encoding: .utf8)
        } else {
            print(out, terminator: "")
        }
    }

    func run() throws {
        do {
            try _run()
        } catch _ as OrionFailure {
            // exit gracefully; OrionFailure means we've already emitted
            // an error message
            throw ExitCode.failure
        }
    }
}

OrionCommand.main()
