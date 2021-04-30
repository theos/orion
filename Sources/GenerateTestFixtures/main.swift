import Foundation
import OrionProcessor

// NOTE: These fixtures double as the glue file for the runtime tests

// we want to scope this so that the objects' deinits are called
do {
    let engine = OrionDiagnosticEngine()
    engine.addConsumer(.printing)

    let orionTests = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../../Tests/OrionTests")

    let parserOptions = OrionParser.Options()
    let data = try OrionBatchParser(inputs: [orionTests], diagnosticEngine: engine, options: parserOptions).parse()
    let generatorOptions = OrionGenerator.Options(emitSourceLocations: false)
    let generator = OrionGenerator(data: data, diagnosticEngine: engine, options: generatorOptions)
    let glue = try generator.generate()

    let dest = orionTests.appendingPathComponent("Generated.xc.swift")
    try glue.write(to: dest, atomically: true, encoding: .utf8)

    print("Wrote glue file to \(dest.standardized.path)")
}
