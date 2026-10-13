// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacSender",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/stasel/WebRTC.git", exact: "132.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MacSender",
            dependencies: [
                .product(name: "WebRTC", package: "WebRTC")
            ],
            path: "Sources"
        )
    ]
)
