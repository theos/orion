// swift-tools-version:5.6

import PackageDescription
import Foundation

let swiftSyntax: Package.Dependency = {
    let url = "https://github.com/apple/swift-syntax"
    #if swift(>=5.9)
    #warning("""
    Orion does not officially support this version of Swift yet. \
    Please check https://github.com/theos/Orion for progress updates.
    """)
    #endif
    #if swift(>=5.8)
    return .package(url: url, from: "508.0.0")
    #elseif swift(>=5.7)
    return .package(url: url, exact: "0.50700.0")
    #elseif swift(>=5.6)
    return .package(url: url, exact: "0.50600.1")
    #else
    #error("""
    Internal error: Swift Package Manager should be reading from
    Package.swift, not Package@swift-5.6.swift.
    """)
    #endif
}()

let macPlatform: SupportedPlatform = {
    #if swift(>=5.8)
    return .macOS("10.15")
    #else
    return .macOS("10.12")
    #endif
}()

var package = Package(
    name: "Orion",
    platforms: [macPlatform],
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
            ]
        ),
        .testTarget(
            name: "OrionProcessorTests",
            dependencies: ["OrionProcessor"]
        ),
        .plugin(
            name: "OrionPlugin",
            capability: .buildTool(),
            dependencies: ["OrionCLI"]
        ),
    ]
)

#if canImport(ObjectiveC)
if ProcessInfo.processInfo.environment["SPM_THEOS_BUILD"] != "1" {
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
