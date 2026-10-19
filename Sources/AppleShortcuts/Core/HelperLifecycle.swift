//
//  HelperLifecycle.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  A helper's life: offered once, checked before every run, run headless,
//  and reported on — by its own tool's `doctor`, or `shortcut helpers` for all.
//
//  MEASURED (macOS 27, agenda's tag helper, 2026-10-19), and why it is shaped
//  so:
//  - Adding takes a person's click; there is no headless import. `offer`
//    opens the signed file and Shortcuts shows its Add sheet.
//  - A shortcut that exits 0 has RUN; it has not shown that anything changed.
//    Edit Reminder's "Add" mode silently behaved as "Set". So `run` returns
//    what the shortcut handed back and nothing more: the caller reads the
//    state it meant to change and compares.
//  - The action catalogue lists App Intents the Mac editor will not import
//    ("contains features not supported on this device"); a recipe that
//    passes `ShortcutBuilder.build` can still be refused at import, so every
//    helper needs one real import before it ships.
//

import Foundation

public extension Helper {

    /// The shortcut as built: the marker comment first, then the steps.
    var recipe: Recipe { HelperMarking.recipe(for: self) }

    /// The marker this build carries.
    var marker: HelperMarker { HelperMarking.marker(for: self) }

    /// Where the tool keeps its offered files:
    /// `~/Library/Application Support/<tool>/shortcuts`. Shortcuts reads the
    /// file after `open` returns, so it must outlive the process.
    var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(tool)/shortcuts", isDirectory: true)
    }

    /// Where it stands in the library.
    func status(host: any HelperHost = LiveHelperHost()) throws -> HelperStatus {
        HelperAssessment.status(of: self, in: try host.installed())
    }

    /// Its status, or ``HelperError/notReady(_:)`` unless it is current.
    @discardableResult
    func requireRunnable(host: any HelperHost = LiveHelperHost()) throws -> HelperStatus {
        let status = try status(host: host)
        guard status.isRunnable else { throw HelperError.notReady(status) }
        return status
    }

    /// Writes, signs and offers it. Nothing is added until a person clicks
    /// Add Shortcut — and, when an older copy is there, Replace.
    ///
    /// - Returns: The signed file.
    func offer(to folder: URL? = nil, host: any HelperHost = LiveHelperHost()) throws -> URL {
        let file = try host.write(recipe, to: folder ?? self.folder)
        try host.offer(file)
        return file
    }

    /// Waits for a person to add it: the status once it is current, or as it
    /// stands when `timeout` runs out.
    func waitUntilInstalled(timeout: Double = 120, interval: Double = 1,
                            host: any HelperHost = LiveHelperHost()) throws -> HelperStatus {
        let deadline = Date().addingTimeInterval(timeout)
        var status = try status(host: host)
        while !status.isRunnable, Date() < deadline {
            Thread.sleep(forTimeInterval: interval)
            status = try self.status(host: host)
        }
        return status
    }

    /// Runs it with `input`, after checking the input against its fields and
    /// the helper against the library.
    ///
    /// - Throws: ``HelperError`` before anything runs;
    ///   ``ShortcutsError/timedOut(_:seconds:)`` when the run outlived
    ///   `timeout` — it may still have done its work.
    /// - Returns: What it handed back. Whether it did what was asked is for
    ///   the caller to read from the state it changed.
    func run(_ input: [String: PlistValue] = [:], host: any HelperHost = LiveHelperHost(),
             onWaiting: (@Sendable () -> Void)? = nil) throws -> RunResult {
        let data = try HelperInputs.encode(input, for: self)
        let status = try requireRunnable(host: host)
        // By identifier: the one shortcut the check just found, whatever else
        // in the library shares its name.
        // Text out as plain text: MEASURED, Use Model's answer came back as RTF
        // ({\\rtf1 … ready}) without it.
        return try host.run(status.shortcutIDs.first ?? name, input: data,
                            outputType: output.type == .text ? "public.plain-text" : nil,
                            patience: patience, timeout: timeout, onWaiting: onWaiting)
    }
}

public extension Helper {

    /// For a helper that acts on items a filter finds: runs it with
    /// `check: true`, which only finds, and hands back what the filter matched,
    /// one per line. A caller acts only when that is exactly its one target —
    /// MEASURED, Find Notes once ignored its filter and the action hit every note.
    func check(_ input: [String: PlistValue], host: any HelperHost = LiveHelperHost(),
               onWaiting: (@Sendable () -> Void)? = nil) throws -> [String] {
        var asked = input
        asked["check"] = .bool(true)
        let output = try run(asked, host: host, onWaiting: onWaiting).output
        return String(decoding: output, as: UTF8.self).split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Whether the helper finds by a filter, and so must be checked before it acts.
    var findsByFilter: Bool { HelperCatalogueCheck.findsByFilter(self) }
}

public extension HelperCatalogue {

    /// One helper by id.
    func helper(_ id: String) -> Helper? { helpers.first { $0.id == id } }

    /// One helper by id, or a programming error: a tool asks only for ids it ships.
    subscript(id: String) -> Helper {
        guard let helper = helper(id) else { preconditionFailure("no helper \(id) in the catalogue") }
        return helper
    }

    /// A tool's helpers.
    func helpers(for tool: String) -> [Helper] { helpers.filter { $0.tool == tool } }

    /// Every helper's standing, every replaced name still installed, and every
    /// marked shortcut whose id is not here.
    func census(host: any HelperHost = LiveHelperHost()) throws -> [HelperStatus] {
        HelperAssessment.census(self, in: try host.installed())
    }

    /// Shortcuts `tool` installed and nothing uses now. Shortcuts cannot be
    /// deleted headless; these are for a person to delete.
    func stale(for tool: String, host: any HelperHost = LiveHelperHost()) throws -> [HelperStatus] {
        HelperAssessment.stale(tool: tool, in: self, library: try host.installed())
    }

    /// Offers every helper in `helpers` that is not current (and not newer),
    /// EACH ONCE, then waits up to `timeout` for a person to add them all.
    ///
    /// Each offer opens one Add sheet; opening the same file twice shows two
    /// sheets and, clicked twice, adds two copies — so nothing here re-offers
    /// while it waits.
    ///
    /// - Returns: Every helper's status at the end, and the ones offered.
    func install(_ helpers: [Helper], timeout: Double = 180, interval: Double = 1, host: any HelperHost = LiveHelperHost(),
                 onOffered: (Helper) -> Void = { _ in }) throws -> (statuses: [HelperStatus], offered: [Helper]) {
        let library = try host.installed()
        let before = helpers.map { HelperAssessment.status(of: $0, in: library) }
        let needed = zip(helpers, before).filter { !$1.isRunnable && $1.state != .newer && $1.state != .duplicated }.map(\.0)
        for helper in needed {
            _ = try helper.offer(host: host)
            onOffered(helper)
        }
        let deadline = Date().addingTimeInterval(timeout)
        var statuses = before
        for helper in needed {
            let status = try helper.waitUntilInstalled(timeout: max(0, deadline.timeIntervalSinceNow), interval: interval, host: host)
            statuses = statuses.map { $0.id == helper.id ? status : $0 }
        }
        return (statuses, needed)
    }

    /// Every problem with the catalogue; empty when it is sound.
    var problems: [String] { HelperCatalogueCheck.problems(self) }

    /// Problems this Mac's action catalogue finds in the steps. Passing is not
    /// importability: each helper still needs one real import.
    func actionProblems(builder: ShortcutBuilder) -> [String] {
        HelperCatalogueCheck.actionProblems(self, builder: builder)
    }
}
