// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ChromeTabManager",
    platforms: [.macOS(.v14)],
    dependencies: [],
    targets: [
        .target(name: "TabTimeShared"),
        .executableTarget(
            name: "ChromeTabManager",
            dependencies: ["TabTimeShared"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .executableTarget(
            name: "TabTimeHost",
            dependencies: ["TabTimeShared"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "ChromeTabManagerTests",
            dependencies: ["ChromeTabManager"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        )
    ]
)
