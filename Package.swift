// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Rewrite",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Rewrite",
            path: "Sources/Rewrite"
        )
    ]
)
