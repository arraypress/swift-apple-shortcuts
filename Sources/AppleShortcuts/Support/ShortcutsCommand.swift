//
//  ShortcutsCommand.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  Apple's `shortcuts` command: what to pass it, and how to read it back.
//

import Foundation

/// Arguments for, and parsing of, `/usr/bin/shortcuts`.
///
/// Pure: nothing here runs the command, so every rule about its output is
/// tested on recorded lines.
enum ShortcutsCommand {

    /// Apple's command, by absolute path.
    static let path = "/usr/bin/shortcuts"

    /// Reads one line of `shortcuts list --show-identifiers`.
    ///
    /// The line is `Name (UUID)`. A name can contain parentheses of its own —
    /// "Resize (fast)" — so the identifier is the LAST parenthesised group,
    /// and only when it is shaped like a UUID.
    static func parseListLine(_ line: Substring) -> (name: String, id: String)? {
        // Newlines too: a line split off a CRLF listing still ends in "\r",
        // and `.whitespaces` does not include it — the test for CRLF input
        // caught every line being rejected.
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix(")"), let open = trimmed.range(of: " (", options: .backwards) else { return nil }
        let id = String(trimmed[open.upperBound..<trimmed.index(before: trimmed.endIndex)])
        guard UUID(uuidString: id) != nil else { return nil }
        return (String(trimmed[..<open.lowerBound]), id)
    }

    /// Every `Name (UUID)` line in a listing.
    ///
    /// Split on the byte, not the Character: `"\r\n"` is one Swift Character,
    /// and a split on `"\n"` finds nothing in text that carries it.
    static func parseList(_ output: Data) -> [(name: String, id: String)] {
        output.split(separator: 0x0A)
            .map { String(decoding: $0, as: UTF8.self) }
            .compactMap { parseListLine(Substring($0)) }
    }

    /// The library error for a failed `shortcuts run`.
    ///
    /// Measured: a name that does not exist exits 1 with
    /// `Error: The operation couldn't be completed. Couldn't find shortcut`
    /// on stderr. Anything else is the shortcut's own failure, in its words.
    static func failure(status: Int32, stderr: String, shortcut: String) -> ShortcutsError {
        let message = stderr
            .replacingOccurrences(of: "Error: ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if message.localizedCaseInsensitiveContains("couldn’t find shortcut")
            || message.localizedCaseInsensitiveContains("couldn't find shortcut") {
            return .noSuchShortcut(shortcut)
        }
        return .runFailed(message.isEmpty ? "exit \(status)" : message)
    }
}
