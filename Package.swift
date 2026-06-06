// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LockType",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "LockType",
            path: "Sources/LockType",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
            ]
        )
    ]
)
