// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TemporaryAI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "TemporaryAI",
            targets: ["TemporaryAI"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TemporaryAI",
            path: "Sources",
            resources: [
                .copy("Resources") 
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
