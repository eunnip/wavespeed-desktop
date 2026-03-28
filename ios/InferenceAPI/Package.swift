// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InferenceAPI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "InferenceAPI", targets: ["InferenceAPI"]),
    ],
    targets: [
        .target(
            name: "InferenceAPI",
            path: "Sources/InferenceAPI"
        ),
    ]
)
