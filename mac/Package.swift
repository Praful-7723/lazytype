// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LazyType",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "LazyTypeCompanion",
            targets: ["RemoteCompanion"]
        )
    ],
    targets: [
        .executableTarget(
            name: "RemoteCompanion",
            path: "Sources/RemoteCompanion"
        )
    ]
)
