// swift-tools-version:5.1

import PackageDescription
import Foundation

enum Builder {
    case theos
    case xcode
    case spm
}

let swiftSyntaxVersion: Version = {
    #if swift(>=5.3)
    #error("""
    Orion does not support this version of Swift yet. \
    Please check https://github.com/theos/Orion for progress updates.
    """)
    #elseif swift(>=5.2)
    return "0.50200.0"
    #elseif swift(>=5.1)
    #error("Orion does not support Swift 5.1 yet, but support is coming soon.")
    return "0.50100.0"
    #else
    #error("Orion does not support versions of Swift lower than 5.1.")
    #endif
}()

let builder: Builder
let env = ProcessInfo.processInfo.environment
if env["SPM_THEOS_BUILD"] == "1" {
    builder = .theos
} else if env["XPC_SERVICE_NAME"]?.hasPrefix("com.apple.dt.Xcode.") == true {
    builder = .xcode
} else {
    builder = .spm
}

let rpathLinkerSettings: [LinkerSetting]? = builder == .xcode ? [
    .unsafeFlags([
        // we need this for SwiftSyntax to find lib_InternalSwiftSyntaxParser.dylib. Not needed if we use
        // generate-xcodeproj but it's required if the package is opened directly.
        "-rpath", "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx"
    ])
] : nil

var package = Package(
    name: "Orion",
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
        .package(url: "https://github.com/apple/swift-syntax.git", .exact(swiftSyntaxVersion)),
    ],
    targets: [
        .target(
            name: "OrionProcessor",
            dependencies: ["SwiftSyntax"]
        ),
        .target(
            name: "OrionProcessorCLI",
            dependencies: ["OrionProcessor"],
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
package.products += [
    .library(
        name: "Orion",
        targets: ["Orion"]
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
    .target(
        name: "OrionTestSupport",
        dependencies: ["Orion"]
    ),
    .testTarget(
        name: "OrionTests",
        dependencies: ["Orion", "OrionTestSupport"]
    ),
]
#endif
