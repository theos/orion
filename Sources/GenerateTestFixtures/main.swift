import Foundation
import OrionProcessor

// NOTE: These fixtures double as the glue file for Hooks.x.swift

let engine = OrionDiagnosticEngine()
engine.addConsumer(.printing)

let orionTests = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("../../Tests/OrionTests")
let contents = try String(contentsOf: orionTests.appendingPathComponent("Hooks.x.swift"))

let data = try OrionParser(contents: contents, diagnosticEngine: engine).parse()
let generator = OrionGenerator(data: data, diagnosticEngine: engine)
let glue = try generator.generate()

let dest = orionTests.appendingPathComponent("Generated.xc.swift")
try glue.write(to: dest, atomically: true, encoding: .utf8)

print("Wrote glue file to \(dest.standardized.path)")
