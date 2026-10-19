//
//  HelperStatus.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One helper's standing, with what to do about it.
public struct HelperStatus: Sendable, Equatable, Codable {

    /// The helper's id; for a shortcut no helper file names, its name.
    public let id: String

    /// The name it should be installed under.
    public let name: String

    /// The tool that owns it.
    public let tool: String

    /// Where it stands.
    public let state: HelperState

    /// The version installed, when one is and it says.
    public let installedVersion: Int?

    /// The version the catalogue has; `nil` for a shortcut it does not name.
    public let wantedVersion: Int?

    /// The shortcuts that are it (several when duplicated).
    public let shortcutIDs: [String]

    /// The name it is installed under, when that is not `name`.
    public let installedName: String?

    /// The command that installs it.
    public let install: String?

    /// Runs Shortcuts has recorded.
    public let runCount: Int

    /// When it last ran.
    public let lastRun: Date?

    /// For a duplicated helper, every copy, the one to keep first.
    public let copies: [HelperCopy]

    /// For a broken helper, what the round-trip lint found.
    public let problems: [String]

    /// A status from its parts.
    public init(id: String, name: String, tool: String, state: HelperState, installedVersion: Int? = nil,
                wantedVersion: Int? = nil, shortcutIDs: [String] = [], installedName: String? = nil,
                install: String? = nil, runCount: Int = 0, lastRun: Date? = nil, copies: [HelperCopy] = [], problems: [String] = []) {
        self.id = id
        self.name = name
        self.tool = tool
        self.state = state
        self.installedVersion = installedVersion
        self.wantedVersion = wantedVersion
        self.shortcutIDs = shortcutIDs
        self.installedName = installedName
        self.install = install
        self.runCount = runCount
        self.lastRun = lastRun
        self.copies = copies
        self.problems = problems
    }
}

/// One copy of a duplicated helper.
public struct HelperCopy: Sendable, Equatable, Codable {
    /// The shortcut's identifier.
    public let id: String
    /// Its name in the library.
    public let name: String
    /// The marker's version, when it has one.
    public let version: Int?
    /// The copy to keep; the rest are to delete.
    public let keep: Bool

    public init(id: String, name: String, version: Int?, keep: Bool) {
        self.id = id
        self.name = name
        self.version = version
        self.keep = keep
    }
}
