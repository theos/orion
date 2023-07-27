import PackagePlugin

@main struct OrionPlugin: BuildToolPlugin {
    private func createCommand(
        orion: Path,
        workDirectory: Path,
        inputs: [Path]
    ) -> Command {
        let output = workDirectory.appending("Generated.xc.swift")
        return .buildCommand(
            displayName: "Run Orion Preprocessor",
            executable: orion,
            arguments: ["--output", output, "--"] + inputs,
            environment: [:],
            inputFiles: inputs,
            outputFiles: [output]
        )
    }

    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        [createCommand(
            orion: try context.tool(named: "OrionCLI").path,
            workDirectory: context.pluginWorkDirectory,
            inputs: [target.directory]
        )]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension OrionPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        [createCommand(
            orion: try context.tool(named: "OrionCLI").path,
            workDirectory: context.pluginWorkDirectory,
            inputs: target.inputFiles
                .filter { $0.type == .source && $0.path.extension == "swift" }
                .map(\.path)
        )]
    }
}
#endif
