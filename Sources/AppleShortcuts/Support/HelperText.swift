//
//  HelperText.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  A helper's standing in words, and the one thing to do about it.
//

import Foundation

enum HelperText {

    /// A short description of the state, for a doctor row.
    static func summary(_ status: HelperStatus) -> String {
        let installed = status.installedVersion.map { "v\($0)" }
        switch status.state {
        case .current:
            return status.wantedVersion == 0 ? "installed (predates helper versions)" : "installed (v\(status.wantedVersion ?? 0))"
        case .missing: return "not installed"
        case .broken: return "BROKEN — " + (status.problems.first ?? "its steps would not run as meant")
        case .outdated: return "out of date (\(installed ?? "v?") installed, v\(status.wantedVersion ?? 0) wanted)"
        case .newer: return "newer than this tool (\(installed ?? "v?") installed, v\(status.wantedVersion ?? 0) known)"
        case .changed: return "changed since it was added (v\(status.installedVersion ?? 0))"
        case .unmarked: return "a shortcut has its name but was not made by \(status.tool)"
        case .misnamed: return "installed as \"\(status.installedName ?? "?")\""
        case .duplicated: return "\(status.shortcutIDs.count) shortcuts answer to it"
        case .obsolete: return "no longer used by \(status.tool)"
        case .unclaimed: return "marked as a helper, but no helper file names it"
        }
    }

    /// Why a helper will not be run.
    static func problem(_ status: HelperStatus) -> String {
        "The \(status.tool) helper shortcut \"\(status.name)\" is \(summary(status))"
    }

    /// What to do. `nil` when nothing needs doing.
    static func remedy(_ status: HelperStatus) -> String? {
        let install = "\(status.install ?? "\(status.tool) doctor --install"), then click Add Shortcut"
        switch status.state {
        case .current: return nil
        case .missing, .outdated, .changed:
            return install + (status.state == .missing ? "" : " and choose Replace")
        case .newer: return "upgrade \(status.tool)"
        case .broken: return "upgrade \(status.tool) when a fixed helper ships, then " + install + " and choose Replace"
        case .unmarked:
            return "rename or delete the shortcut \"\(status.name)\" in Shortcuts, then " + install
        case .misnamed:
            return "in Shortcuts, delete any old \"\(status.name)\" and rename \"\(status.installedName ?? "?")\" to \"\(status.name)\""
        case .duplicated:
            let delete = status.copies.filter { !$0.keep }.map { "\"\($0.name)\"" }
            guard let keep = status.copies.first(where: \.keep), !delete.isEmpty else {
                return "in Shortcuts, keep one \"\(status.name)\" and delete the rest (`shortcut helpers` lists them)"
            }
            let rename = AssessmentNames.same(keep.name, status.name) ? "" : ", then rename \"\(keep.name)\" to \"\(status.name)\""
            return "in Shortcuts, delete \(delete.joined(separator: " and ")) and keep \"\(keep.name)\"\(rename)"
        case .obsolete, .unclaimed:
            return "delete \"\(status.installedName ?? status.name)\" in Shortcuts"
        }
    }
}

public extension HelperStatus {

    /// Whether a run would be accepted.
    var isRunnable: Bool { state == .current }

    /// The state in a few words: `out of date (v1 installed, v2 wanted)`.
    var summary: String { HelperText.summary(self) }

    /// The one thing to do, or `nil` when nothing needs doing.
    var remedy: String? { HelperText.remedy(self) }
}

enum AssessmentNames {
    static func same(_ lhs: String, _ rhs: String) -> Bool { HelperAssessment.same(lhs, rhs) }
}
