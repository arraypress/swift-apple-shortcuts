//
//  HelperAssessment.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  Where a helper stands, from a list of what the library holds. Pure: every
//  rule here is tested on lists, without Shortcuts.
//

import Foundation

enum HelperAssessment {

    /// One helper's standing.
    ///
    /// The marker decides what a shortcut IS; the name only what it would be
    /// run as. So a marked copy under another name is `misnamed`, a shortcut
    /// with the name and no marker is `unmarked`, and two that would answer to
    /// the same run are `duplicated` — never "whichever came first". A helper
    /// at version 0 predates markers and is known by its name alone.
    static func status(of helper: Helper, in library: [InstalledShortcut]) -> HelperStatus {
        let marked = library.filter { $0.marker?.id == helper.id }
        // A copy Shortcuts made with "Keep Both" — "<name> 1" — is a copy even unmarked.
        let named = library.filter { (same($0.name, helper.name) || isCopy($0.name, of: helper.name)) && !marked.contains($0) }
        let all = marked + named

        func status(_ state: HelperState, _ entry: InstalledShortcut? = nil) -> HelperStatus {
            HelperStatus(id: helper.id, name: helper.name, tool: helper.tool, state: state,
                         installedVersion: entry?.marker?.version, wantedVersion: helper.version,
                         shortcutIDs: entry.map { [$0.id] } ?? all.map(\.id),
                         installedName: entry.flatMap { same($0.name, helper.name) ? nil : $0.name },
                         install: helper.install, runCount: entry?.runCount ?? 0, lastRun: entry?.lastRun,
                         copies: state == .duplicated ? copies(all, of: helper) : [],
                         problems: entry?.problems ?? [])
        }

        if all.isEmpty { return status(.missing) }
        if all.count > 1 {
            // Several answer to it. The copy to keep runs by its identifier, so a
            // stray old copy is never run — but only when the keeper is itself
            // exactly this helper, current and clean.
            let duplicated = status(.duplicated)
            guard let keep = duplicated.copies.first, let entry = all.first(where: { $0.id == keep.id }),
                  same(entry.name, helper.name), entry.marker?.version == helper.version,
                  entry.marker?.recipe == HelperMarking.fingerprint(helper), entry.problems.isEmpty,
                  helper.input.isEmpty || entry.noInputBehavior == HelperLint.stopsOnNoInput else { return duplicated }
            return HelperStatus(id: helper.id, name: helper.name, tool: helper.tool, state: .duplicated,
                                installedVersion: helper.version, wantedVersion: helper.version,
                                shortcutIDs: [keep.id] + duplicated.shortcutIDs.filter { $0 != keep.id }, install: helper.install,
                                runCount: entry.runCount, lastRun: entry.lastRun, copies: duplicated.copies, keeperRuns: true)
        }
        let entry = all[0]
        if helper.version == 0, entry.marker == nil { return status(.current, entry) }
        guard let marker = entry.marker, marked.contains(entry) else { return status(.unmarked, entry) }
        if !same(entry.name, helper.name) { return status(.misnamed, entry) }
        if marker.version < helper.version { return status(.outdated, entry) }
        if marker.version > helper.version { return status(.newer, entry) }
        if marker.recipe != HelperMarking.fingerprint(helper) { return status(.changed, entry) }
        if !entry.problems.isEmpty { return status(.broken, entry) }
        if !helper.input.isEmpty, entry.noInputBehavior != HelperLint.stopsOnNoInput {
            return HelperStatus(id: helper.id, name: helper.name, tool: helper.tool, state: .broken, installedVersion: marker.version,
                                wantedVersion: helper.version, shortcutIDs: [entry.id], install: helper.install,
                                runCount: entry.runCount, lastRun: entry.lastRun,
                                problems: ["run by hand with no input it asks for each parameter instead of stopping"])
        }
        return status(.current, entry)
    }

    /// Shortcuts a tool installed and no longer uses: its helpers' `replaces`
    /// names, and anything marked with one of the tool's ids that the
    /// catalogue no longer has.
    static func stale(tool: String, in catalogue: HelperCatalogue, library: [InstalledShortcut]) -> [HelperStatus] {
        census(catalogue, in: library).filter { $0.tool == tool && ($0.state == .obsolete || $0.state == .unclaimed) }
    }

    /// Every helper in the catalogue, every replaced name still installed,
    /// and every marked shortcut whose id the catalogue does not have.
    static func census(_ catalogue: HelperCatalogue, in library: [InstalledShortcut]) -> [HelperStatus] {
        var rows = catalogue.helpers.map { status(of: $0, in: library) }
        var reported = Set(rows.flatMap(\.shortcutIDs))

        for helper in catalogue.helpers {
            for old in helper.replaces {
                for entry in library where same(entry.name, old) && !reported.contains(entry.id) {
                    reported.insert(entry.id)
                    rows.append(HelperStatus(id: helper.id, name: old, tool: helper.tool, state: .obsolete,
                                             installedVersion: entry.marker?.version, shortcutIDs: [entry.id],
                                             runCount: entry.runCount, lastRun: entry.lastRun))
                }
            }
        }
        for entry in library where !reported.contains(entry.id) {
            guard let marker = entry.marker else { continue }
            rows.append(HelperStatus(id: marker.id, name: entry.name,
                                     tool: String(marker.id.prefix { $0 != "." }), state: .unclaimed,
                                     installedVersion: marker.version, shortcutIDs: [entry.id],
                                     runCount: entry.runCount, lastRun: entry.lastRun))
        }
        return rows.sorted { ($0.tool, $0.name.lowercased()) < ($1.tool, $1.name.lowercased()) }
    }

    /// Whether `name` is `<helper> 1`, `<helper> 2`… — Shortcuts' name for a
    /// second copy.
    static func isCopy(_ name: String, of helper: String) -> Bool {
        guard name.count > helper.count + 1, same(String(name.prefix(helper.count)), helper) else { return false }
        let rest = name.dropFirst(helper.count)
        return rest.first == " " && rest.dropFirst().allSatisfy(\.isNumber) && rest.count > 1
    }

    /// The copies, the one to keep first: marked as this version (the real
    /// helper), then named exactly, then the newest.
    static func copies(_ all: [InstalledShortcut], of helper: Helper) -> [HelperCopy] {
        func rank(_ entry: InstalledShortcut) -> Int {
            let exact = same(entry.name, helper.name)
            let marked = entry.marker?.id == helper.id && entry.marker?.version == helper.version
            return (marked ? 2 : 0) + (exact ? 1 : 0)
        }
        let ordered = all.sorted {
            rank($0) != rank($1) ? rank($0) > rank($1) : ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast)
        }
        return ordered.enumerated().map { HelperCopy(id: $1.id, name: $1.name, version: $1.marker?.version, keep: $0 == 0) }
    }

    /// Names compared without case: a difference in case is not a safe way to
    /// tell two shortcuts apart.
    static func same(_ lhs: String, _ rhs: String) -> Bool {
        lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }
}
