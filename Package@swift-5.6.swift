// swift-tools-version:5.6

import PackageDescription
import Foundation

enum Builder {
    case theos
    case xcode
    case spm
}

let swiftSyntax: Package.Dependency = {
    #if swift(>=5.8)
    #error("""
    Orion does not support this version of Swift yet. \
    Please check https://github.com/theos/Orion for progress updates.
    """)
    #elseif swift(>=5.7)
    return .package(url: "https://github.com/apple/swift-syntax", exact: "0.50700.0")
    #elseif swift(>=5.6)
    return .package(url: "https://github.com/apple/swift-syntax.git", exact: "0.50600.1")
    #else
    #error("""
    Internal error: Swift Package Manager should be reading from
    Package.swift, not Package@swift-5.6.swift.
    """)
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

func system(_ path: String, _ args: String...) -> String {
    let pipe = Pipe()
    let process = Process()
    process.launchPath = path
    process.arguments = args
    process.standardOutput = pipe
    process.standardError = nil
    process.launch()
    process.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// allow lib_InternalSwiftSyntaxParser to be located at runtime. Based on
// https://github.com/muter-mutation-testing/muter/blob/dc53a9cd1792b2ffd3c9a1a0795aae99e8c7334d/Package.swift#L40
let rpathLinkerSettings: [LinkerSetting]? = {
    #if os(macOS)
    let xcrunSwiftPath = system("/usr/bin/xcrun", "-f", "swift")
    let overriddenPrefix = URL(fileURLWithPath: xcrunSwiftPath)
        .deletingLastPathComponent().deletingLastPathComponent()

    let defaultPlatformPath = system("/usr/bin/xcodebuild", "-version", "-sdk", "macosx", "PlatformPath")
    let defaultPrefix = URL(fileURLWithPath: defaultPlatformPath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Toolchains/XcodeDefault.xctoolchain/usr")

    let computedPrefix: URL
    if overriddenPrefix == defaultPrefix {
        // there's no explicit toolchain override. A more specific override may exist
        // inside the PATH
        let xcodebuildPath = system("/usr/bin/type", "-p", "xcodebuild")
        let platformPath = system(xcodebuildPath, "-version", "-sdk", "macosx", "PlatformPath")
        computedPrefix = URL(fileURLWithPath: platformPath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Toolchains/XcodeDefault.xctoolchain/usr")
    } else {
        computedPrefix = overriddenPrefix
    }

    let rpath = computedPrefix.appendingPathComponent("lib/swift/macosx")
    return [
        .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", rpath.path])
    ]
    #else
    // TODO: Do we need an rpath here too?
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
            name: "OrionCLI",
            targets: ["OrionCLI"]
        ),
        .plugin(
            name: "OrionPlugin",
            targets: ["OrionPlugin"]
        ),
    ],
    dependencies: [
        swiftSyntax,
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "OrionProcessor",
            dependencies: [
                .product(name: "SwiftSyntaxParser", package: "swift-syntax")
            ]
        ),
        .executableTarget(
            name: "OrionCLI",
            dependencies: [
                "OrionProcessor",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            linkerSettings: rpathLinkerSettings
        ),
        .testTarget(
            name: "OrionProcessorTests",
            dependencies: ["OrionProcessor"],
            linkerSettings: rpathLinkerSettings
        ),
        .plugin(
            name: "OrionPlugin",
            capability: .buildTool(),
            dependencies: ["OrionCLI"]
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
        .executableTarget(
            name: "OrionPlayground",
            dependencies: ["Orion", "OrionTestSupport"]
        ),
        .target(
            name: "OrionTestSupport",
            dependencies: ["Orion"]
        ),
        .testTarget(
            name: "OrionTests",
            dependencies: ["Orion", "OrionBackend_Fishhook", "OrionTestSupport"],
            plugins: ["OrionPlugin"]
        ),
    ]
}
#endif
