// swift-tools-version:5.2

import PackageDescription
import Foundation

enum Builder {
    case theos
    case xcode
    case spm
}

let swiftSyntaxVersion: Package.Dependency.Requirement = {
    #if swift(>=5.5)
    #error("""
    Orion does not support this version of Swift yet. \
    Please check https://github.com/theos/Orion for progress updates.
    """)
    #elseif swift(>=5.4)
    return .exact("0.50400.0")
    #elseif swift(>=5.3)
    return .exact("0.50300.0")
    #elseif swift(>=5.2)
    return .exact("0.50200.0")
    #else
    #error("Orion does not support versions of Swift lower than 5.2.")
    #endif
}()

let builder: Builder
let env = ProcessInfo.processInfo.environment
if env["SPM_THEOS_BUILD"] == "1" {
    builder = .theos
} else if env["XPC_SERVICE_NAME"]?.contains("com.apple.dt.Xcode.") == true {
    builder = .xcode
} else {
    builder = .spm
}

// based on
// https://github.com/muter-mutation-testing/muter/blob/dc53a9cd1792b2ffd3c9a1a0795aae99e8c7334d/Package.swift#L40
let rpathLinkerSettings: [LinkerSetting]? = {
    #if os(macOS)
    guard builder == .xcode else { return nil }

    let stdout = Pipe()
    let select = Process()
    // this is better than $(xcode-select -p) because what we're actually looking
    // for is the Swift resource dir, which is relative to the swift executable.
    // The swift executable that xcrun finds may not be in the developer dir, eg
    // when using TOOLCHAINS=swift
    select.launchPath = "/usr/bin/xcrun"
    select.arguments = ["-f", "swift"]
    select.standardOutput = stdout
    select.standardError = nil
    select.launch()
    select.waitUntilExit()

    let swiftPath = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let resDir = URL(fileURLWithPath: swiftPath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("lib/swift/macosx")
    return [
        .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", resDir.path])
    ]
    #else
    return nil
    #endif
}()

var package = Package(
    name: "Orion",
    platforms: [.macOS("10.12")],
    products: [
        .library(
            name: "OrionProcessor",
            targets: ["OrionProcessor"]
        ),
        .executable(
            name: "orion",
            targets: ["OrionProcessorCLI"]
        ),
        .executable(
            name: "generate-test-fixtures",
            targets: ["GenerateTestFixtures"]
        ),
    ],
    dependencies: [
//        .package(url: "https://github.com/jpsim/SourceKitten", .upToNextMajor(from: "0.29.0")),
        .package(name: "SwiftSyntax", url: "https://github.com/apple/swift-syntax.git", swiftSyntaxVersion),
        .package(name: "swift-argument-parser", url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.4.0")),
    ],
    targets: [
        .target(
            name: "OrionProcessor",
            dependencies: ["SwiftSyntax"]
        ),
        .target(
            name: "OrionProcessorCLI",
            dependencies: [
                "OrionProcessor",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            linkerSettings: rpathLinkerSettings
        ),
        .target(
            name: "GenerateTestFixtures",
            dependencies: ["OrionProcessor"],
            linkerSettings: rpathLinkerSettings
        ),
        .testTarget(
            name: "OrionProcessorTests",
            dependencies: ["OrionProcessor"],
            linkerSettings: rpathLinkerSettings
        ),
    ]
)

#if canImport(ObjectiveC)
if builder != .theos {
    package.products += [
        .library(
            name: "Orion",
            targets: ["Orion"]
        ),
        .library(
            name: "CydiaSubstrate",
            targets: ["CydiaSubstrate"]
        ),
        .library(
            name: "OrionBackend_Substrate",
            targets: ["OrionBackend_Substrate"]
        ),
        .executable(
            name: "OrionPlayground",
            targets: ["OrionPlayground"]
        ),
    ]

    package.targets += [
        .target(
            name: "OrionC",
            dependencies: []
        ),
        .target(
            name: "Orion",
            dependencies: ["OrionC"]
        ),
        .systemLibrary(
            name: "CydiaSubstrate"
        ),
        .target(
            name: "OrionBackend_Substrate",
            dependencies: ["CydiaSubstrate", "Orion"]
        ),
        .target(
            name: "Fishhook"
        ),
        .target(
            name: "OrionBackend_Fishhook",
            dependencies: ["Fishhook", "Orion"]
        ),
        .target(
            name: "OrionPlayground",
            dependencies: ["Orion", "OrionTestSupport"]
        ),
        .target(
            name: "OrionTestSupport",
            dependencies: ["Orion"]
        ),
        .testTarget(
            name: "OrionTests",
            dependencies: ["Orion", "OrionBackend_Fishhook", "OrionTestSupport"]
        ),
    ]
}
#endif
