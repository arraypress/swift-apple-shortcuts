//
//  ShortcutsError.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong listing, running or building shortcuts.
public enum ShortcutsError: Error, Equatable, Sendable, LocalizedError {

    /// No shortcut with that name or identifier.
    case noSuchShortcut(String)

    /// No folder with that name or identifier.
    ///
    /// Checked here because the system command does not: measured,
    /// `shortcuts list --folder-name <a folder that does not exist>` lists
    /// EVERY shortcut and exits 0 — an answer to a different question that
    /// looks exactly like the right one.
    case noSuchFolder(String)

    /// Several shortcuts share that name. Carries their identifiers.
    case ambiguous(String, [String])

    /// A store this library reads is there, but may not be read.
    case notPermitted(String)

    /// The action catalogue is missing — Shortcuts has never indexed this Mac.
    case noCatalogue(String)

    /// A store could not be read.
    case readFailed(String)

    /// No action with that identifier in the catalogue. Carries the closest
    /// identifiers, for a caller who misspelt one.
    case unknownAction(String, suggestions: [String])

    /// An action was given a parameter it does not have. Carries the ones it
    /// does.
    case unknownParameter(action: String, key: String, valid: [String])

    /// A recipe could not be read.
    case invalidRecipe(String)

    /// `shortcuts sign` refused.
    case signingFailed(String)

    /// The shortcut ran and failed, in its own words.
    case runFailed(String)

    /// The run did not finish in time.
    ///
    /// The usual cause, measured: Shortcuts asks on screen before a shortcut
    /// may hand its output to a command line — "Allow … to output 1 text
    /// item?" — once per shortcut, and the run waits for that click.
    case timedOut(String, seconds: Double)

    /// Shortcuts Events, or the `shortcuts` command, could not be asked.
    case unavailable(String)

    /// A sentence a person can act on.
    public var errorDescription: String? {
        switch self {
        case .noSuchShortcut(let name):
            "No shortcut called \(name)"
        case .noSuchFolder(let name):
            "No folder called \(name)"
        case .ambiguous(let name, let ids):
            "\(ids.count) shortcuts are called \(name) — use an identifier"
        case .notPermitted(let path):
            "Not allowed to read \(path) — grant Full Disk Access to your terminal in "
                + "System Settings ▸ Privacy & Security ▸ Full Disk Access"
        case .noCatalogue(let path):
            "No action catalogue at \(path) — open Shortcuts once so it can index this Mac"
        case .readFailed(let reason):
            "Could not read Shortcuts' data: \(reason)"
        case .unknownAction(let id, let suggestions):
            suggestions.isEmpty
                ? "No action \(id)"
                : "No action \(id) — did you mean \(suggestions.joined(separator: ", "))?"
        case .unknownParameter(let action, let key, let valid):
            "\(action) has no parameter \(key)"
                + (valid.isEmpty ? " — it takes none" : " — it takes \(valid.joined(separator: ", "))")
        case .invalidRecipe(let reason):
            "That recipe could not be read: \(reason)"
        case .signingFailed(let reason):
            "Signing failed: \(reason)"
        case .runFailed(let reason):
            "The shortcut failed: \(reason)"
        case .timedOut(let name, let seconds):
            "\(name) did not finish in \(Int(seconds)) s — Shortcuts may be asking for permission on screen"
        case .unavailable(let reason):
            "Shortcuts could not be reached: \(reason)"
        }
    }
}
