//
//  Helper.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A shortcut a command-line tool depends on: added once by a person, then
/// run in the background with JSON in and, where there is one, an answer out.
///
/// Much of what a Mac can do is reachable only as a Shortcuts action, and a
/// shortcut cannot be added without a person's click. So a tool that needs
/// one ships it as a helper — one JSON file in this package's `Helpers/`
/// folder, compiled in — offered once, checked before every run, and reported
/// by the tool's `doctor` and by `shortcut helpers` as installed, missing or
/// out of date.
///
/// In the library every helper looks the same: named `<tool> · <title>`, the
/// fleet's one tile colour, and a comment at the top saying what it does,
/// which tool installed it, and the line the tool recognises it by:
/// `[helper id=settings.focus version=1 recipe=3f9a1c2e]`.
public struct Helper: Sendable, Equatable {

    /// `<tool>.<what>` — `settings.focus`. Never changes once shipped.
    public let id: String

    /// The command-line tool that owns it — `settings`, `notes`.
    public let tool: String

    /// What it does, in two or three words — `Set Focus`.
    public let title: String

    /// One line, plain English, shown at the top of the shortcut.
    public let description: String

    /// Raised whenever a caller depends on a change: the input it reads, the
    /// output it gives, what it does. 0 only for a helper from before markers.
    public let version: Int

    /// Its tile.
    public let icon: HelperIcon

    /// The JSON fields it reads.
    public let input: [HelperField]

    /// What it hands back.
    public let output: HelperOutput

    /// The steps, without the marker comment.
    public let steps: [RecipeStep]

    /// Limits and requirements worth knowing — "needs Apple Intelligence".
    public let notes: [String]

    /// Shortcut names an earlier design installed and nothing uses now.
    public let replaces: [String]

    /// The command that offers it: `settings doctor --install`.
    public let install: String

    /// The name it is installed under when that is not `<tool> · <title>` —
    /// only for a helper from before the convention.
    public let legacyName: String?

    /// Shipped knowing the lint fails on it: installable for a person to look
    /// at, reported BROKEN, never run.
    public let experimental: Bool

    /// Seconds before a run is reported as waiting on Shortcuts.
    public let patience: Double

    /// Seconds before a run is given up on.
    public let timeout: Double

    /// A helper from its parts. The catalogue reads them from JSON.
    public init(id: String, tool: String, title: String, description: String, version: Int,
                icon: HelperIcon = HelperIcon(glyph: HelperPalette.defaultGlyph),
                input: [HelperField] = [], output: HelperOutput = HelperOutput(type: .none),
                steps: [RecipeStep], notes: [String] = [], replaces: [String] = [], install: String? = nil,
                legacyName: String? = nil, experimental: Bool = false, patience: Double = 5, timeout: Double = 30) {
        self.id = id
        self.tool = tool
        self.title = title
        self.description = description
        self.version = version
        self.icon = icon
        self.input = input
        self.output = output
        self.steps = steps
        self.notes = notes
        self.replaces = replaces
        self.install = install ?? "\(tool) doctor --install"
        self.legacyName = legacyName
        self.experimental = experimental
        self.patience = patience
        self.timeout = timeout
    }
}
