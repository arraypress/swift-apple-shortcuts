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
        // The fleet's shared helper verbs: `<tool> doctor` and the exit codes
        // for helper refusals, written once instead of once per tool.
        .library(name: "AppleShortcutsCLI", targets: ["AppleShortcutsCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/arraypress/swift-cli-kit.git", from: "0.20.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/arraypress/swift-sqlite-reader.git", from: "0.2.0"),
    ],
    targets: [
        .target(name: "AppleShortcuts", dependencies: [
            .product(name: "SQLiteReader", package: "swift-sqlite-reader"),
        ]),
        .target(name: "AppleShortcutsCLI", dependencies: [
            "AppleShortcuts",
            .product(name: "CLIKit", package: "swift-cli-kit"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .testTarget(name: "AppleShortcutsTests", dependencies: ["AppleShortcuts"]),
        .testTarget(name: "AppleShortcutsCLITests", dependencies: [
            "AppleShortcutsCLI", "AppleShortcuts",
            .product(name: "CLIKit", package: "swift-cli-kit"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
