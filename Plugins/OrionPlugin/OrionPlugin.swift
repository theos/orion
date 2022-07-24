import PackagePlugin

@main struct OrionPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let tool = try context.tool(named: "OrionCLI")
        let output = context.pluginWorkDirectory.appending("Generated.xc.swift")
        return [.buildCommand(
            displayName: "Run Orion Preprocessor",
            executable: tool.path,
            arguments: ["--output", output, "--", target.directory],
            environment: [:],
            inputFiles: [target.directory],
            outputFiles: [output]
        )]
    }
}
