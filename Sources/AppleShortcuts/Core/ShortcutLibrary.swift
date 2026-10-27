//
//  ShortcutLibrary.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  The shortcuts this Mac has: listed, found, and read step by step.
//

import Foundation
import SQLiteReader

/// The shortcuts in this Mac's library.
///
/// Listing goes through Apple's `shortcuts` command — 0.01 s, measured, and
/// the one interface Apple supports for it. Reading what a shortcut DOES goes
/// to the library's own database, read-only, because nothing else will say:
/// the scripting dictionary offers an action count, and measured on a
/// shortcut built by this library it reported **0** for a shortcut whose one
/// action was sitting in the database.
///
/// ```swift
/// let library = ShortcutLibrary()
/// for shortcut in try library.shortcuts() {
///     print(shortcut.name, shortcut.folder ?? "—")
/// }
/// ```
public struct ShortcutLibrary: Sendable {

    /// Where the library's database lives.
    public let databasePath: String

    /// A library, defaulting to this user's.
    public init(databasePath: String? = nil) {
        self.databasePath = databasePath ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Shortcuts/Shortcuts.sqlite").path
    }

    // MARK: - Listing

    /// Every shortcut, each with its folder.
    ///
    /// - Parameter folder: Only this folder — a name or identifier.
    /// - Throws: ``ShortcutsError/noSuchFolder(_:)`` for a folder that does
    ///   not exist, which the system command answers with every shortcut.
    public func shortcuts(in folder: String? = nil) throws -> [Shortcut] {
        let folders = try self.folders()

        // Membership is read one folder at a time: `list` has no column for
        // it, and the database keeps it in sync blobs nobody documents.
        var membership: [String: String] = [:]
        for each in folders {
            for entry in try list(["--folder-name", each.id]) { membership[entry.id] = each.name }
        }

        if let folder {
            guard let chosen = Self.folder(folder, in: folders) else { throw ShortcutsError.noSuchFolder(folder) }
            return try list(["--folder-name", chosen.id]).map {
                Shortcut(id: $0.id, name: $0.name, folder: chosen.name)
            }
        }
        return try list([]).map { Shortcut(id: $0.id, name: $0.name, folder: membership[$0.id]) }
    }

    /// Every folder.
    public func folders() throws -> [ShortcutFolder] {
        try list(["--folders"]).map { ShortcutFolder(id: $0.id, name: $0.name) }
    }

    /// The one shortcut a name or identifier names.
    ///
    /// An identifier first, then a name exactly, then a name ignoring case.
    /// Two shortcuts may share a name, and running "whichever came first" is
    /// running the wrong one half the time — so that is refused, with both
    /// identifiers.
    public func shortcut(_ nameOrID: String) throws -> Shortcut {
        let all = try shortcuts()
        if let byID = all.first(where: { $0.id.caseInsensitiveCompare(nameOrID) == .orderedSame }) {
            return byID
        }
        var matches = all.filter { $0.name == nameOrID }
        if matches.isEmpty {
            matches = all.filter { $0.name.caseInsensitiveCompare(nameOrID) == .orderedSame }
        }
        switch matches.count {
        case 0: throw ShortcutsError.noSuchShortcut(nameOrID)
        case 1: return matches[0]
        default: throw ShortcutsError.ambiguous(nameOrID, matches.map(\.id))
        }
    }

    // MARK: - Reading a shortcut

    /// What a shortcut does, step by step.
    ///
    /// - Parameter catalog: Names each step's action, when given.
    public func steps(of shortcut: Shortcut, catalog: ActionCatalog? = nil) throws -> [ShortcutStep] {
        let database = try SQLiteReader.shortcutsStore(databasePath)
        var blob: Data?
        try database.read("""
            select a.ZDATA from ZSHORTCUTACTIONS a
            join ZSHORTCUT s on a.ZSHORTCUT = s.Z_PK
            where s.ZWORKFLOWID = ? and coalesce(s.ZTOMBSTONED, 0) = 0
            limit 1
            """, [.text(shortcut.id)]) { row in blob = row[0].nonEmptyData }

        guard let blob else { return [] }
        let steps = try StepDecoding.steps(from: blob)
        guard let catalog else { return steps }
        return steps.map {
            ShortcutStep(action: $0.action, name: try? catalog.action(id: $0.action).name, parameters: $0.parameters)
        }
    }

    // MARK: - Helpers

    /// Every shortcut with its helper marker (when it carries one), run count
    /// and last run — in one read of the library's database.
    ///
    /// The run count and date are Shortcuts' own (`ZRUNEVENTSCOUNT`,
    /// `ZLASTRUNEVENTDATE`), which count runs from the command line too.
    public func installed() throws -> [InstalledShortcut] {
        let database = try SQLiteReader.shortcutsStore(databasePath)
        var found: [InstalledShortcut] = []
        try database.read("""
            select s.ZWORKFLOWID, s.ZNAME, s.ZRUNEVENTSCOUNT, s.ZLASTRUNEVENTDATE, s.ZMODIFICATIONDATE,
                   (select a.ZDATA from ZSHORTCUTACTIONS a where a.ZSHORTCUT = s.Z_PK limit 1), s.ZNOINPUTBEHAVIORDATA
            from ZSHORTCUT s
            where coalesce(s.ZTOMBSTONED, 0) = 0 and s.ZWORKFLOWID is not null
            order by s.ZNAME
            """) { row in
            let steps = row[5].nonEmptyData.flatMap { try? StepDecoding.steps(from: $0) } ?? []
            let marker = HelperMarking.marker(in: steps)
            found.append(InstalledShortcut(
                id: row[0].string ?? "",
                name: row[1].string ?? "",
                marker: marker,
                runCount: row[2].int ?? 0,
                lastRun: row[3].double.map(Date.init(timeIntervalSinceReferenceDate:)),
                modified: row[4].double.map(Date.init(timeIntervalSinceReferenceDate:)),
                problems: marker == nil ? [] : HelperLint.problems(steps),
                noInputBehavior: row[6].nonEmptyData.flatMap(HelperLint.noInputBehaviorName)
            ))
        }
        return found
    }

    // MARK: - Internals

    /// One run of `shortcuts list`.
    private func list(_ arguments: [String]) throws -> [(name: String, id: String)] {
        guard let outcome = try ProcessRunner.run(
            ShortcutsCommand.path, ["list", "--show-identifiers"] + arguments, timeout: 30
        ) else { throw ShortcutsError.timedOut("shortcuts list", seconds: 30) }
        guard outcome.status == 0 else {
            throw ShortcutsError.unavailable(outcome.error.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return ShortcutsCommand.parseList(outcome.output)
    }

    /// A folder by identifier, then name, then name ignoring case.
    static func folder(_ wanted: String, in folders: [ShortcutFolder]) -> ShortcutFolder? {
        folders.first { $0.id.caseInsensitiveCompare(wanted) == .orderedSame }
            ?? folders.first { $0.name == wanted }
            ?? folders.first { $0.name.caseInsensitiveCompare(wanted) == .orderedSame }
    }
}
