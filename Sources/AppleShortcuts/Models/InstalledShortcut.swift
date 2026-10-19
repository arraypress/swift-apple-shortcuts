//
//  InstalledShortcut.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A shortcut in the library, as a helper check sees it: its marker, when it
/// carries one, and how much it is used.
public struct InstalledShortcut: Sendable, Equatable, Codable, Identifiable {

    /// The shortcut's identifier.
    public let id: String

    /// The name it runs by.
    public let name: String

    /// The helper marker in its first comment step, when there is one.
    public let marker: HelperMarker?

    /// Runs Shortcuts has recorded.
    public let runCount: Int

    /// When it last ran, if ever.
    public let lastRun: Date?

    /// When it was last changed — for a helper, when it was added.
    public let modified: Date?

    /// What the round-trip lint finds in its stored steps (empty for a shortcut
    /// that is not a helper, which is not linted).
    public let problems: [String]

    /// What it does when run with no input: the behaviour's name, as stored
    /// (`WFWorkflowNoInputBehaviorShowError`); `nil` for Shortcuts' default.
    public let noInputBehavior: String?

    /// An entry from its parts.
    public init(id: String, name: String, marker: HelperMarker? = nil, runCount: Int = 0,
                lastRun: Date? = nil, modified: Date? = nil, problems: [String] = [],
                noInputBehavior: String? = nil) {
        self.id = id
        self.name = name
        self.marker = marker
        self.runCount = runCount
        self.lastRun = lastRun
        self.modified = modified
        self.problems = problems
        self.noInputBehavior = noInputBehavior
    }
}
