//
//  HelperHost.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  Everything a helper needs from the outside world, in one seam, so a tool's
//  tests can run every helper path against a fake Shortcuts.
//

import Foundation

/// What helpers are checked, offered and run through.
public protocol HelperHost: Sendable {

    /// What the library holds now.
    func installed() throws -> [InstalledShortcut]

    /// Writes a recipe as a signed file in `folder`.
    func write(_ recipe: Recipe, to folder: URL) throws -> URL

    /// Opens a signed file, so Shortcuts shows its Add sheet.
    func offer(_ file: URL) throws

    /// Runs a shortcut by name.
    func run(_ name: String, input: Data?, patience: Double, timeout: Double,
             onWaiting: (@Sendable () -> Void)?) throws -> RunResult

    /// Runs a shortcut, asking for its output as `outputType` (a UTI).
    func run(_ name: String, input: Data?, outputType: String?, patience: Double, timeout: Double,
             onWaiting: (@Sendable () -> Void)?) throws -> RunResult
}

public extension HelperHost {
    /// A host that cannot ask for an output type runs as asked without one.
    func run(_ name: String, input: Data?, outputType: String?, patience: Double, timeout: Double,
             onWaiting: (@Sendable () -> Void)?) throws -> RunResult {
        try run(name, input: input, patience: patience, timeout: timeout, onWaiting: onWaiting)
    }
}

/// Shortcuts itself: the library's database, `shortcuts sign`, `open` and
/// `shortcuts run`.
public struct LiveHelperHost: HelperHost {

    /// The library read.
    public let library: ShortcutLibrary

    /// This user's library.
    public init(library: ShortcutLibrary = ShortcutLibrary()) {
        self.library = library
    }

    public func installed() throws -> [InstalledShortcut] { try library.installed() }

    public func write(_ recipe: Recipe, to folder: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try ShortcutBuilder().write(recipe, to: folder)
    }

    public func offer(_ file: URL) throws { try ShortcutBuilder.offer(file) }

    public func run(_ name: String, input: Data?, patience: Double, timeout: Double,
                    onWaiting: (@Sendable () -> Void)?) throws -> RunResult {
        try run(name, input: input, outputType: nil, patience: patience, timeout: timeout, onWaiting: onWaiting)
    }

    public func run(_ name: String, input: Data?, outputType: String?, patience: Double, timeout: Double,
                    onWaiting: (@Sendable () -> Void)?) throws -> RunResult {
        try ShortcutRunner.run(name, input: input, outputType: outputType, patience: patience, timeout: timeout, onWaiting: onWaiting)
    }
}
