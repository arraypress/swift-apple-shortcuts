//
//  ShortcutRunner.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  Running a shortcut and taking what it hands back.
//

import Foundation

/// Runs shortcuts in the background, through Apple's `shortcuts` command.
///
/// No window opens: a run of a one-action shortcut took **0.13–0.17 s**,
/// measured, with Shortcuts.app never launched.
///
/// **The first run of each shortcut may wait on a person.** Before a shortcut
/// can hand its output to a command line, Shortcuts asks on screen — "Allow
/// … to output 1 text item?", with Don't Allow, Allow Once and Always Allow.
/// Measured: the run sat for 18.8 s until it was answered, then printed its
/// output and exited 0; after Always Allow it never asked again. So a run
/// takes a `patience` after which the caller is told the run is waiting, and
/// an optional `timeout` after which it is stopped.
public enum ShortcutRunner {

    /// Runs a shortcut.
    ///
    /// - Parameters:
    ///   - shortcut: A name or identifier.
    ///   - input: Bytes to hand the shortcut, written to a temporary file for
    ///     the run and deleted after. Measured: a shortcut reading `$input`
    ///     got the file's TEXT, not its name — "hi there" in, "You said: hi
    ///     there" out — so text input needs no conversion.
    ///   - inputFile: A file to hand it instead.
    ///   - outputType: A UTI to ask for the output as — `public.plain-text`.
    ///   - patience: Seconds before `onWaiting` is called.
    ///   - timeout: Seconds before the run is stopped. `nil` waits for ever,
    ///     which is right when a person is there to answer the prompt.
    public static func run(
        _ shortcut: String,
        input: Data? = nil,
        inputFile: URL? = nil,
        outputType: String? = nil,
        patience: Double = 5,
        timeout: Double? = nil,
        onWaiting: (@Sendable () -> Void)? = nil
    ) throws -> RunResult {
        var arguments = ["run", shortcut, "--output-path", "-"]
        if let outputType { arguments += ["--output-type", outputType] }

        var temporary: URL?
        defer { temporary.map { try? FileManager.default.removeItem(at: $0) } }
        if let inputFile {
            arguments += ["--input-path", inputFile.path]
        } else if let input {
            let file = FileManager.default.temporaryDirectory
                .appendingPathComponent("shortcut-input-\(UUID().uuidString).txt")
            try input.write(to: file)
            temporary = file
            arguments += ["--input-path", file.path]
        }

        guard let outcome = try ProcessRunner.run(
            ShortcutsCommand.path, arguments, patience: patience, timeout: timeout, onWaiting: onWaiting
        ) else {
            throw ShortcutsError.timedOut(shortcut, seconds: timeout ?? 0)
        }
        guard outcome.status == 0 else {
            throw ShortcutsCommand.failure(status: outcome.status, stderr: outcome.error, shortcut: shortcut)
        }
        return RunResult(output: outcome.output, duration: outcome.duration)
    }
}
