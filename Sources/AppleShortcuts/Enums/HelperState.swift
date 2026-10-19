//
//  HelperState.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Where a helper stands in the library.
public enum HelperState: String, Sendable, Equatable, Codable, CaseIterable {

    /// Installed, this version, these steps. The only state a run accepts.
    case current

    /// Not in the library.
    case missing

    /// Installed as this version, but its stored steps fail the round-trip
    /// lint: the Mac editor would not run it as meant. Never run.
    case broken

    /// Installed as an older version.
    case outdated

    /// Installed as a newer version than this tool knows — the tool is the
    /// old one.
    case newer

    /// Same version, different steps: edited by hand, or built from a Mac
    /// whose choices (Focus modes, say) have changed since.
    case changed

    /// A shortcut with the helper's name that carries no marker: made by hand,
    /// or by a tool from before helpers were marked.
    case unmarked

    /// The helper is there, but under another name — Shortcuts' "Keep Both"
    /// adds a second copy as "name 1".
    case misnamed

    /// More than one shortcut claims to be it.
    case duplicated

    /// A name a helper replaced, still installed — nothing uses it; delete it.
    case obsolete

    /// Marked as a helper, but no helper file has its id any more.
    case unclaimed
}
