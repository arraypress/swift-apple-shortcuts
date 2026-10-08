//
//  ProcessRunner.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  Running a system command, with a clock on it.
//

import Foundation

/// Runs a binary and collects what it printed.
enum ProcessRunner {

    /// What a finished command left behind.
    struct Outcome: Sendable {
        /// The exit status.
        let status: Int32
        /// Standard output, whole.
        let output: Data
        /// Standard error, as text.
        let error: String
        /// Wall-clock seconds.
        let duration: Double
    }

    /// Runs a command to completion, or until `timeout`.
    ///
    /// - Parameters:
    ///   - executable: An absolute path — never looked up on PATH, so a
    ///     `shortcuts` earlier on somebody's PATH cannot stand in for Apple's.
    ///   - patience: After this long, `onWaiting` is called once. A shortcut
    ///     waiting on Shortcuts' output prompt sits silent; this is how a
    ///     caller gets to say so rather than look hung.
    ///   - timeout: Give up after this long and terminate the command.
    /// - Returns: `nil` when the timeout passed.
    static func run(
        _ executable: String,
        _ arguments: [String],
        patience: Double? = nil,
        timeout: Double? = nil,
        onWaiting: (@Sendable () -> Void)? = nil
    ) throws -> Outcome? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        // Read both pipes as the command runs. Waiting first and reading
        // after deadlocks on any output larger than the pipe buffer: the
        // command blocks writing, and nothing is reading.
        let collected = Collected()
        let group = DispatchGroup()
        for (pipe, isError) in [(output, false), (error, true)] {
            group.enter()
            DispatchQueue.global().async {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                collected.store(data, isError: isError)
                group.leave()
            }
        }

        let started = Date()
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do {
            try process.run()
        } catch {
            throw ShortcutsError.unavailable("could not run \(executable): \(error.localizedDescription)")
        }

        // Waits for the command, until the deadline if there is one.
        let deadline = timeout.map { DispatchTime.now() + $0 }
        func finishes() -> Bool {
            guard let deadline else { finished.wait(); return true }
            return finished.wait(timeout: deadline) == .success
        }

        let done: Bool
        if let patience, let onWaiting, finished.wait(timeout: .now() + patience) == .timedOut {
            onWaiting()
            done = finishes()
        } else if patience != nil, onWaiting != nil {
            done = true
        } else {
            done = finishes()
        }
        guard done else {
            process.terminate()
            return nil
        }

        group.wait()
        return Outcome(
            status: process.terminationStatus,
            output: collected.output,
            error: String(decoding: collected.error, as: UTF8.self),
            duration: Date().timeIntervalSince(started)
        )
    }

    /// The two pipes' contents, filled from two threads.
    private final class Collected: @unchecked Sendable {
        private let lock = NSLock()
        private var out = Data()
        private var err = Data()

        func store(_ data: Data, isError: Bool) {
            lock.lock()
            defer { lock.unlock() }
            if isError { err = data } else { out = data }
        }

        var output: Data { lock.lock(); defer { lock.unlock() }; return out }
        var error: Data { lock.lock(); defer { lock.unlock() }; return err }
    }
}
