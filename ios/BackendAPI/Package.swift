// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BackendAPI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "BackendAPI", targets: ["BackendAPI"]),
    ],
    targets: [
        .target(
            name: "BackendAPI",
            path: "Sources/BackendAPI"
        ),
    ]
)
