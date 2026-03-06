// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ccMenuBar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ccMenuBar",
            path: "Sources"
        )
    ]
)
