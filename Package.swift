// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "便签 Pro",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "便签 Pro", targets: ["便签 Pro"])
    ],
    targets: [
        .executableTarget(
            name: "便签 Pro",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
