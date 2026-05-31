// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QuickNote",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "QuickNote", targets: ["QuickNote"])
    ],
    targets: [
        .executableTarget(
            name: "QuickNote",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
