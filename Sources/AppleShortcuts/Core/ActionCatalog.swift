//
//  ActionCatalog.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  Every action this Mac can put in a shortcut, from Shortcuts' own index.
//

import Foundation

/// Shortcuts' index of every action every installed app offers.
///
/// Shortcuts keeps it as a SQLite file — `~/Library/Shortcuts/ToolKit/Tools-prod.v<n>-<uuid>.sqlite`
/// — and this reads it read-only. On the Mac this was built on: **2,094
/// actions from 89 apps**, each with its parameters, their types and, for an
/// enumeration, the values it takes. Set Focus, Set Volume, Set Appearance,
/// Wi-Fi, Home scenes — everything Apple exposes only as a Shortcuts action
/// is in here, under the identifier a shortcut file uses.
///
/// ```swift
/// let catalog = try ActionCatalog()
/// for action in try catalog.search("volume") {
///     print(action.id, action.name)
/// }
/// ```
public final class ActionCatalog {

    private let database: SQLiteDatabase

    /// Where the catalogue lives.
    public let path: String

    /// The locale names are read in. English, falling back to the first
    /// locale an entry has.
    public let locale: String

    /// Opens the catalogue.
    ///
    /// - Parameter path: The file to read. Defaults to the newest on this Mac.
    public init(path: String? = nil, locale: String = "en") throws {
        let resolved = try path ?? Self.defaultPath()
        self.path = resolved
        self.locale = locale
        self.database = try SQLiteDatabase(path: resolved)
    }

    /// The newest catalogue file.
    ///
    /// The `v79` in the name is the catalogue's format and the UUID is per
    /// device; both change, so this looks for whatever is there and takes the
    /// most recently written rather than naming one.
    public static func defaultPath() throws -> String {
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Shortcuts/ToolKit", isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let candidates = names
            .filter { $0.hasPrefix("Tools-prod.") && $0.hasSuffix(".sqlite") }
            .map { folder.appendingPathComponent($0) }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return a > b
            }
        guard let newest = candidates.first else { throw ShortcutsError.noCatalogue(folder.path) }
        return newest.path
    }

    // MARK: - Reading

    /// Actions whose name, identifier, summary or app matches, best first.
    ///
    /// - Parameters:
    ///   - text: What to look for. Empty lists everything.
    ///   - app: Only actions from this app — a bundle identifier or name.
    ///   - limit: How many to return.
    public func search(_ text: String = "", app: String? = nil, limit: Int = 50) throws -> [CatalogAction] {
        let (sql, values) = CatalogQueries.search(text: text, app: app, locale: locale, limit: limit)
        var found: [CatalogAction] = []
        try database.query(sql, values) { row in
            found.append(CatalogQueries.action(from: row))
        }
        return try found.map { try withParameters($0) }
    }

    /// One action by identifier, with its parameters.
    public func action(id: String) throws -> CatalogAction {
        let (sql, values) = CatalogQueries.action(id: id, locale: locale)
        var found: CatalogAction?
        try database.query(sql, values) { row in
            if found == nil { found = CatalogQueries.action(from: row) }
        }
        guard let found else {
            throw ShortcutsError.unknownAction(id, suggestions: RecipeValidation.suggestions(for: id, in: try identifiers()))
        }
        return try withParameters(found)
    }

    /// Every action identifier.
    public func identifiers() throws -> [String] {
        var ids: [String] = []
        try database.query("select distinct id from Tools order by id") { row in
            if let id = row.text(0) { ids.append(id) }
        }
        return ids
    }

    /// The apps that offer actions, with how many each.
    public func apps() throws -> [(app: String, name: String?, actions: Int)] {
        var apps: [(String, String?, Int)] = []
        try database.query(CatalogQueries.apps, [.text(locale)]) { row in
            apps.append((row.text(0) ?? "", row.text(1), Int(row.integer(2))))
        }
        return apps
    }

    /// An action with its parameters filled in.
    private func withParameters(_ action: CatalogAction) throws -> CatalogAction {
        var parameters: [CatalogParameter] = []
        try database.query(CatalogQueries.parameters, [.text(action.id), .text(action.app), .text(locale)]) { row in
            parameters.append(CatalogParameter(
                key: row.text(0) ?? "",
                name: row.text(1),
                description: row.text(2),
                type: row.text(3),
                choices: (row.text(4) ?? "").split(separator: "\u{1F}").map(String.init)
            ))
        }
        return CatalogAction(
            id: action.id, name: action.name, summary: action.summary, app: action.app,
            appName: action.appName, kind: action.kind, outputName: action.outputName,
            parameters: parameters
        )
    }
}
