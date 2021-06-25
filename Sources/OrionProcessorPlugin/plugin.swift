import PackagePlugin

let inputFiles = targetBuildContext.inputFiles.map(\.path).filter { $0.extension == "swift" }
let outputFile = targetBuildContext.outputDirectory.appending("Generated.xc.swift")
let arguments = ["--output", outputFile.string] + inputFiles.map(\.string)

commandConstructor.createBuildCommand(
    displayName: "Running OrionProcessor",
    executable: try targetBuildContext.tool(named: "OrionProcessorCLI").path,
    arguments: arguments,
    inputFiles: inputFiles,
    outputFiles: [outputFile]
)
