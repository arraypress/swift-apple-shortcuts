//
//  CatalogQueries.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  The SQL the action catalogue is read with, and how its rows become values.
//

import Foundation
import SQLiteReader

/// Queries against Shortcuts' ToolKit database.
///
/// The schema is Apple's and undocumented; these were written against the
/// `v79` catalogue on macOS 27 and read only the tables whose meaning was
/// checked by eye: `Tools`, `ToolLocalizations`, `ContainerMetadata`,
/// `Parameters`, `ParameterLocalizations`, `ToolParameterTypes` and
/// `EnumerationCases`. Values are always bound, never pasted.
enum CatalogQueries {

    /// The columns every action query selects, in ``action(from:)``'s order.
    static let actionColumns = """
        t.id, l.name, l.descriptionSummary, c.id, cl.name, t.toolType, l.outputResultName, t.visibilityFlags, t.requirements
        """

    /// The joins every action query uses: an action, its app, and both their
    /// names in one locale (bound as `?1`).
    static let actionJoins = """
        from Tools t
        join ContainerMetadata c on c.rowId = t.sourceContainerId
        join ToolLocalizations l on l.toolId = t.rowId and l.locale = ?1
        left join ContainerMetadataLocalizations cl on cl.containerId = c.rowId and cl.locale = ?1
        """

    /// Actions matching some text, exact names first.
    ///
    /// Deprecated actions are left out: the catalogue keeps them so old
    /// shortcuts still open, and each one names its replacement — which is
    /// the one a new shortcut should use.
    static func search(text: String, app: String?, locale: String, limit: Int) -> (String, [SQLiteValue]) {
        let wanted = text.trimmingCharacters(in: .whitespaces).lowercased()
        let like = "%\(wanted)%"
        let sql = """
            select \(actionColumns) \(actionJoins)
            where t.deprecationReplacementId is null
              and (?2 = '' or lower(l.name) like ?3 or lower(t.id) like ?3
                   or lower(coalesce(l.descriptionSummary, '')) like ?3 or lower(coalesce(cl.name, '')) like ?3)
              and (?4 = '' or lower(c.id) = lower(?4) or lower(coalesce(cl.name, '')) = lower(?4))
            group by t.rowId
            order by case
                when lower(l.name) = ?2 then 0
                when lower(l.name) like ?6 or lower(l.name) like ?7 then 1
                when lower(l.name) like ?3 then 2
                else 3 end,
              length(l.name), l.name
            limit ?5
            """
        // A whole word beats letters inside one: asked for "focus", Set Focus
        // must come before Add OmniFocus Item — measured, it did not appear
        // in the first five until this was added.
        return (sql, [.text(locale), .text(wanted), .text(like), .text(app ?? ""), .integer(Int64(limit)),
                      .text("\(wanted)%"), .text("% \(wanted)%")])
    }

    /// One action by identifier.
    ///
    /// An identifier can appear under more than one app — an intent an app
    /// declares and Shortcuts also attributes elsewhere — so the first, by
    /// row, is the one taken: it is the one Shortcuts indexed first.
    static func action(id: String, locale: String) -> (String, [SQLiteValue]) {
        ("select \(actionColumns) \(actionJoins) where t.id = ?2 order by t.rowId limit 1",
         [.text(locale), .text(id)])
    }

    /// An action's parameters: key, name, description, type, and the
    /// enumeration's values joined by U+001F.
    ///
    /// Bound as `?1` the action, `?2` its app, `?3` the locale.
    static let parameters = """
        select p.key, pl.name, pl.description, tp.typeId,
               (select group_concat(e.id, char(31)) from EnumerationCases e
                 where e.typeId = tp.typeId and e.locale = ?3)
        from Tools t
        join ContainerMetadata c on c.rowId = t.sourceContainerId
        join Parameters p on p.toolId = t.rowId
        left join ParameterLocalizations pl on pl.toolId = t.rowId and pl.key = p.key and pl.locale = ?3
        left join ToolParameterTypes tp on tp.toolId = t.rowId and tp.key = p.key
        where t.id = ?1 and c.id = ?2
        group by p.key
        order by p.sortOrder
        """

    /// Apps with how many actions each, most first. Bound `?1` the locale.
    static let apps = """
        select c.id, cl.name, count(distinct t.id)
        from Tools t
        join ContainerMetadata c on c.rowId = t.sourceContainerId
        left join ContainerMetadataLocalizations cl on cl.containerId = c.rowId and cl.locale = ?1
        where t.deprecationReplacementId is null
        group by c.id
        order by 3 desc, c.id
        """

    /// An action from a row of ``actionColumns``, parameters not yet read.
    static func action(from row: SQLiteRow) -> CatalogAction {
        CatalogAction(
            id: row[0].string ?? "",
            name: row[1].string ?? row[0].string ?? "",
            summary: row[2].string.flatMap { $0.isEmpty ? nil : $0 },
            app: row[3].string ?? "",
            appName: row[4].string,
            kind: row[5].string ?? "",
            outputName: row[6].string.flatMap { $0.isEmpty ? nil : $0 },
            mac: PlatformRequirements.availability(visibility: row[7].int ?? 0, requirements: row[8].nonEmptyData ?? Data())
        )
    }
}
