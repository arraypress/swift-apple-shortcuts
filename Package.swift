// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-apple-shortcuts",
    platforms: [
        // macOS only, and not by choice: the `shortcuts` command, the
        // Shortcuts Events scripting host and the action catalogue this reads
        // exist nowhere else. iOS runs shortcuts but gives a third-party
        // process no way to list, run or build them.
        .macOS(.v14)
    ],
    products: [
        .library(name: "AppleShortcuts", targets: ["AppleShortcuts"]),
    ],
    targets: [
        .target(name: "AppleShortcuts"),
        .testTarget(name: "AppleShortcutsTests", dependencies: ["AppleShortcuts"]),
    ]
)
