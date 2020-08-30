// swift-tools-version:5.1

import PackageDescription

let swiftSyntaxVersion: Version = {
    #if swift(>=5.3)
    #error("""
    Logos.swift does not support this version of Swift yet. \
    Please check https://github.com/theos/Logos.swift for progress updates.
    """)
    #elseif swift(>=5.2)
    return "0.50200.0"
    #elseif swift(>=5.1)
    #error("Logos.swift does not support Swift 5.1 yet, but support is planned.")
    return "0.50100.0"
    #else
    #error("Logos.swift does not support versions of Swift lower than 5.1.")
    #endif
}()

var package = Package(
    name: "LogosSwift",
    products: [
        .library(
            name: "LogosSwiftProcessor",
            targets: ["LogosSwiftProcessor"]
        ),
        .executable(
            name: "logos-swift",
            targets: ["LogosSwiftProcessorCLI"]
        ),
    ],
    dependencies: [
//        .package(url: "https://github.com/jpsim/SourceKitten", .upToNextMajor(from: "0.29.0")),
        .package(url: "https://github.com/apple/swift-syntax.git", .exact(swiftSyntaxVersion)),
    ],
    targets: [
        .target(
            name: "LogosSwiftProcessor",
            dependencies: ["SwiftSyntax"]
        ),
        .target(
            name: "LogosSwiftProcessorCLI",
            dependencies: ["LogosSwiftProcessor"]
//            linkerSettings: [
//                .unsafeFlags(
//                    // we need this for SwiftSyntax to find lib_InternalSwiftSyntaxParser.dylib. Not needed if we use
//                    // generate-xcodeproj but it's required if the package is opened directly.
//                    ["-rpath", "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx"],
//                    .when(platforms: [.macOS])
//                )
//            ]
        ),
        .testTarget(
            name: "LogosSwiftProcessorTests",
            dependencies: ["LogosSwiftProcessor"],
            linkerSettings: [
                .unsafeFlags(
                    // we need this for SwiftSyntax to find lib_InternalSwiftSyntaxParser.dylib. Not needed if we use
                    // generate-xcodeproj but it's required if the package is opened directly.
                    ["-rpath", "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx"],
                    .when(platforms: [.macOS])
                )
            ]
        ),
    ]
)

#if canImport(ObjectiveC)
package.products += [
    .library(
        name: "LogosSwift",
        targets: ["LogosSwift"]
    ),
]

package.targets += [
    .target(
        name: "LogosSwiftC",
        dependencies: []
    ),
    .target(
        name: "LogosSwift",
        dependencies: ["LogosSwiftC"]
    ),
    .target(
        name: "LogosSwiftTestSupport",
        dependencies: ["LogosSwift"]
    ),
    .testTarget(
        name: "LogosSwiftTests",
        dependencies: ["LogosSwift", "LogosSwiftTestSupport"]
    ),
]
#endif
