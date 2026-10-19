//
//  HelperTests.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  Helpers against a fake Shortcuts: nothing here opens Shortcuts, adds a
//  shortcut or runs one. The library scan runs on a SQLite file made here in
//  the shape of Shortcuts' own.
//

import SQLite3
import XCTest
@testable import AppleShortcuts

/// A Shortcuts that records what it was asked and answers from a list.
final class FakeHost: HelperHost, @unchecked Sendable {
    var library: [InstalledShortcut]
    var runs: [(name: String, input: Data?, patience: Double, timeout: Double)] = []
    var outputTypes: [String?] = []
    var offered: [URL] = []
    var written: [Recipe] = []
    var output = Data()
    /// Called on each `installed()`, so a test can change the library mid-wait.
    var onList: ((FakeHost) -> Void)?

    init(_ library: [InstalledShortcut] = []) { self.library = library }

    func installed() throws -> [InstalledShortcut] {
        onList?(self)
        return library
    }
    func write(_ recipe: Recipe, to folder: URL) throws -> URL {
        written.append(recipe)
        return folder.appendingPathComponent(ShortcutBuilder.fileName(for: recipe.name))
    }
    func offer(_ file: URL) throws { offered.append(file) }
    func run(_ name: String, input: Data?, patience: Double, timeout: Double,
             onWaiting: (@Sendable () -> Void)?) throws -> RunResult {
        try run(name, input: input, outputType: nil, patience: patience, timeout: timeout, onWaiting: onWaiting)
    }
    func run(_ name: String, input: Data?, outputType: String?, patience: Double, timeout: Double,
             onWaiting: (@Sendable () -> Void)?) throws -> RunResult {
        runs.append((name, input, patience, timeout))
        outputTypes.append(outputType)
        return RunResult(output: output, duration: 0.1)
    }
}

final class HelperTests: XCTestCase {

    let focus = Helper(id: "settings.focus", tool: "settings", title: "Set Focus",
                       description: "Turns a Focus on or off.", version: 2,
                       icon: HelperIcon(glyph: 61440),
                       input: [HelperField(name: "on", type: .bool, description: "on or off"),
                               HelperField(name: "mode", type: .string, required: false, description: "which",
                                           choices: ["Work", "Sleep"])],
                       output: HelperOutput(type: .text),
                       steps: [RecipeStep(action: "is.workflow.actions.dnd.set", parameters: ["Enabled": .bool(true)])],
                       replaces: ["settings dnd"], patience: 3, timeout: 20)

    var catalogue: HelperCatalogue { HelperCatalogue(helpers: [focus]) }

    func entry(_ name: String, marker: HelperMarker?, id: String = UUID().uuidString) -> InstalledShortcut {
        InstalledShortcut(id: id, name: name, marker: marker, runCount: 4,
                          lastRun: Date(timeIntervalSinceReferenceDate: 100), noInputBehavior: HelperLint.stopsOnNoInput)
    }

    func marker(version: Int? = nil, recipe: String? = nil, id: String? = nil) -> HelperMarker {
        HelperMarker(id: id ?? focus.id, version: version ?? focus.version, recipe: recipe ?? HelperMarking.fingerprint(focus))
    }

    // MARK: - Naming and the marker

    func testTheNameIsToolDotTitleUnlessLegacy() {
        XCTAssertEqual(focus.name, "settings · Set Focus")
        let legacy = Helper(id: "agenda.set-tags", tool: "agenda", title: "Set Tags", description: "d", version: 0,
                            steps: [], legacyName: "agenda set tags")
        XCTAssertEqual(legacy.name, "agenda set tags")
        XCTAssertEqual(focus.install, "settings doctor --install")
    }

    func testTheRecipeIsMarkedNamedAndOnTheFleetTile() {
        let recipe = focus.recipe
        XCTAssertEqual(recipe.name, "settings · Set Focus")
        XCTAssertEqual(recipe.icon, RecipeIcon(color: 3_031_607_807, glyph: 61440))
        XCTAssertEqual(recipe.actions.first?.action, "is.workflow.actions.comment")
        XCTAssertEqual(Array(recipe.actions.dropFirst()), focus.steps)
        guard case .string(let text)? = recipe.actions.first?.parameters["WFCommentActionText"] else {
            return XCTFail("no comment text")
        }
        XCTAssertTrue(text.hasPrefix("Turns a Focus on or off.\n\nInstalled by settings — don't edit; reinstall with `settings doctor --install`."))
        XCTAssertFalse(text.lowercased().contains("arraypress"))
        XCTAssertEqual(HelperMarking.parse(text), focus.marker)
    }

    func testAHelperWithInputStopsWhenRunByHandAndOneThatAsksIsBroken() {
        let context = RecipeEncoding.Context(outputName: { _ in nil }, isTextParameter: { _, _ in true })
        let behaviour = RecipeEncoding.workflow(focus.recipe, context: context)["WFWorkflowNoInputBehavior"] as? [String: Any]
        XCTAssertEqual(behaviour?["Name"] as? String, "WFWorkflowNoInputBehaviorShowError")
        let message = (behaviour?["Parameters"] as? [String: Any])?["Error"] as? String
        XCTAssertEqual(message, "This is a helper for the settings command-line tool, which runs it with its input. Don't run it by hand.")
        let noInput = Helper(id: "settings.focus-get", tool: "settings", title: "Get Focus", description: "d", version: 1,
                             steps: [RecipeStep(action: "is.workflow.actions.dnd.getfocus")])
        XCTAssertNil(RecipeEncoding.workflow(noInput.recipe, context: context)["WFWorkflowNoInputBehavior"])
        let asks = InstalledShortcut(id: "A", name: focus.name, marker: marker())
        let status = HelperAssessment.status(of: focus, in: [asks])
        XCTAssertEqual(status.state, .broken)
        XCTAssertEqual(status.problems, ["run by hand with no input it asks for each parameter instead of stopping"])
        XCTAssertEqual(HelperAssessment.status(of: noInput, in: [InstalledShortcut(id: "B", name: noInput.name, marker: noInput.marker)]).state, .current)
    }

    func testTheIconReachesTheFile() {
        let context = RecipeEncoding.Context(outputName: { _ in nil }, isTextParameter: { _, _ in true })
        let icon = RecipeEncoding.workflow(focus.recipe, context: context)["WFWorkflowIcon"] as? [String: Int]
        XCTAssertEqual(icon, ["WFWorkflowIconStartColor": 3_031_607_807, "WFWorkflowIconGlyphNumber": 61440])
        let plain = RecipeEncoding.workflow(Recipe(name: "x", actions: []), context: context)["WFWorkflowIcon"] as? [String: Int]
        XCTAssertEqual(plain, ["WFWorkflowIconStartColor": 4_282_601_983, "WFWorkflowIconGlyphNumber": 59511])
    }

    func testTheMarkerLineRoundTrips() {
        let line = HelperMarking.line(for: focus.marker)
        XCTAssertEqual(line, "[helper id=settings.focus version=2 recipe=\(focus.marker.recipe)]")
        XCTAssertEqual(HelperMarking.parse("some words\n\n" + line + "\n"), focus.marker)
        XCTAssertNil(HelperMarking.parse("[helper id=settings.focus version=one recipe=0123abcd]"))
        XCTAssertNil(HelperMarking.parse("[helper id=Settings version=1 recipe=0123abcd]"))
        XCTAssertNil(HelperMarking.parse("no marker here"))
    }

    func testOnlyTheFirstCommentIsAClaim() {
        let quoted = ShortcutStep(action: "is.workflow.actions.comment",
                                  parameters: ["WFCommentActionText": .string(HelperMarking.line(for: focus.marker))])
        let plain = ShortcutStep(action: "is.workflow.actions.comment", parameters: ["WFCommentActionText": .string("notes")])
        let other = ShortcutStep(action: "is.workflow.actions.gettext")
        XCTAssertEqual(HelperMarking.marker(in: [other, quoted]), focus.marker)
        XCTAssertNil(HelperMarking.marker(in: [plain, quoted]))
        XCTAssertNil(HelperMarking.marker(in: [other]))
    }

    func testTheFingerprintFollowsNameAndStepsNotWording() {
        func variant(title: String = "Set Focus", version: Int = 2, description: String = "x", enabled: Bool = true) -> Helper {
            Helper(id: "settings.focus", tool: "settings", title: title, description: description, version: version,
                   steps: [RecipeStep(action: "is.workflow.actions.dnd.set", parameters: ["Enabled": .bool(enabled)])])
        }
        XCTAssertEqual(HelperMarking.fingerprint(variant(version: 9, description: "Other words.")), HelperMarking.fingerprint(focus))
        XCTAssertNotEqual(HelperMarking.fingerprint(variant(enabled: false)), HelperMarking.fingerprint(focus))
        XCTAssertNotEqual(HelperMarking.fingerprint(variant(title: "Focus")), HelperMarking.fingerprint(focus))
        XCTAssertEqual(HelperMarking.fingerprint(focus).count, 8)
    }

    // MARK: - Status

    func testStates() {
        func state(_ library: [InstalledShortcut]) -> HelperState {
            HelperAssessment.status(of: focus, in: library).state
        }
        XCTAssertEqual(state([]), .missing)
        XCTAssertEqual(state([entry("Something else", marker: nil)]), .missing)
        XCTAssertEqual(state([entry("settings · Set Focus", marker: marker())]), .current)
        XCTAssertEqual(state([entry("Settings · set focus", marker: marker())]), .current)
        XCTAssertEqual(state([entry("settings · Set Focus", marker: marker(version: 1))]), .outdated)
        XCTAssertEqual(state([entry("settings · Set Focus", marker: marker(version: 3))]), .newer)
        XCTAssertEqual(state([entry("settings · Set Focus", marker: marker(recipe: "00000000"))]), .changed)
        XCTAssertEqual(state([entry("settings · Set Focus", marker: nil)]), .unmarked)
        XCTAssertEqual(state([entry("settings · Set Focus", marker: marker(id: "notes.tag"))]), .unmarked)
        XCTAssertEqual(state([entry("settings · Set Focus 1", marker: marker())]), .misnamed)
        XCTAssertEqual(state([entry("settings · Set Focus", marker: marker()), entry("settings · Set Focus 1", marker: marker())]), .duplicated)
        XCTAssertEqual(state([entry("settings · Set Focus", marker: nil), entry("x", marker: marker())]), .duplicated)
    }

    func testAStatusCarriesWhatADoctorRowNeeds() {
        let status = HelperAssessment.status(of: focus, in: [entry("settings · Set Focus 1", marker: marker(version: 1), id: "A-B")])
        XCTAssertEqual(status.state, .misnamed)
        XCTAssertEqual(status.id, "settings.focus")
        XCTAssertEqual(status.installedName, "settings · Set Focus 1")
        XCTAssertEqual(status.installedVersion, 1)
        XCTAssertEqual(status.wantedVersion, 2)
        XCTAssertEqual(status.shortcutIDs, ["A-B"])
        XCTAssertEqual(status.install, "settings doctor --install")
        XCTAssertEqual(status.runCount, 4)
        XCTAssertEqual(status.lastRun, Date(timeIntervalSinceReferenceDate: 100))
        XCTAssertFalse(status.isRunnable)
        XCTAssertEqual(status.summary, "installed as \"settings · Set Focus 1\"")
    }

    func testRemediesNameTheFix() {
        func remedy(_ state: HelperState, install: String? = "notes tag --install") -> String? {
            HelperStatus(id: "x.y", name: "notes · Tag", tool: "notes", state: state, installedName: "old", install: install).remedy
        }
        XCTAssertNil(remedy(.current))
        XCTAssertEqual(remedy(.missing), "notes tag --install, then click Add Shortcut")
        XCTAssertEqual(remedy(.outdated), "notes tag --install, then click Add Shortcut and choose Replace")
        XCTAssertEqual(remedy(.missing, install: nil), "notes doctor --install, then click Add Shortcut")
        XCTAssertEqual(remedy(.newer), "upgrade notes")
        XCTAssertEqual(remedy(.obsolete), "delete \"old\" in Shortcuts")
    }

    func testAHelperFromBeforeMarkersIsKnownByName() {
        let legacy = Helper(id: "agenda.set-tags", tool: "agenda", title: "Set Tags", description: "d", version: 0,
                            steps: [], legacyName: "agenda set tags")
        let status = HelperAssessment.status(of: legacy, in: [entry("agenda set tags", marker: nil)])
        XCTAssertEqual(status.state, .current)
        XCTAssertEqual(status.summary, "installed (predates helper versions)")
        XCTAssertEqual(HelperAssessment.status(of: focus, in: [entry(focus.name, marker: nil)]).state, .unmarked)
    }

    // MARK: - Input

    func testInputIsCheckedAgainstTheFields() throws {
        XCTAssertNil(HelperInputs.problem(["on": .bool(true)], for: focus))
        XCTAssertNil(HelperInputs.problem(["on": .bool(true), "mode": .string("Work")], for: focus))
        XCTAssertEqual(HelperInputs.problem([:], for: focus), "\"on\" is required")
        XCTAssertEqual(HelperInputs.problem(["on": .string("yes")], for: focus), "\"on\" is a bool")
        XCTAssertEqual(HelperInputs.problem(["on": .bool(true), "mode": .string("Play")], for: focus),
                       "\"mode\" is one of Work, Sleep, not Play")
        XCTAssertEqual(HelperInputs.problem(["on": .bool(true), "moed": .string("Work")], for: focus),
                       "it takes no \"moed\" (it takes mode, on)")
        let numbers = Helper(id: "a.b", tool: "a", title: "B", description: "d", version: 1,
                             input: [HelperField(name: "n", type: .number, description: ""),
                                     HelperField(name: "l", type: .list, description: "")], steps: [])
        XCTAssertNil(HelperInputs.problem(["n": .double(0.5), "l": .array([])], for: numbers))
        XCTAssertNil(HelperInputs.problem(["n": .integer(3), "l": .array([.string("a")])], for: numbers))
        XCTAssertEqual(HelperInputs.problem(["n": .integer(3), "l": .string("a")], for: numbers), "\"l\" is a list")
        let data = try HelperInputs.encode(["on": .bool(true), "mode": .string("a/b")], for:
            Helper(id: "a.b", tool: "a", title: "B", description: "d", version: 1,
                   input: [HelperField(name: "on", type: .bool, description: ""),
                           HelperField(name: "mode", type: .string, description: "")], steps: []))
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"mode":"a/b","on":true}"#)
    }

    // MARK: - Running

    func testARunIsRefusedBeforeAnythingRunsUnlessCurrent() throws {
        for library in [[], [entry(focus.name, marker: marker(version: 1))], [entry(focus.name, marker: nil)]] {
            let host = FakeHost(library)
            XCTAssertThrowsError(try focus.run(["on": .bool(true)], host: host)) { error in
                guard case HelperError.notReady(let status)? = error as? HelperError else { return XCTFail("\(error)") }
                XCTAssertFalse(status.isRunnable)
            }
            XCTAssertTrue(host.runs.isEmpty)
        }
    }

    func testBadInputIsRefusedBeforeTheLibraryIsEvenAsked() {
        let host = FakeHost([entry(focus.name, marker: marker())])
        var listed = 0
        host.onList = { _ in listed += 1 }
        XCTAssertThrowsError(try focus.run(["on": .string("x")], host: host)) {
            XCTAssertEqual($0 as? HelperError, .invalidInput(id: "settings.focus", reason: "\"on\" is a bool"))
        }
        XCTAssertEqual(listed, 0)
        XCTAssertTrue(host.runs.isEmpty)
    }

    func testARunPassesNameInputPatienceAndTimeout() throws {
        let host = FakeHost([entry(focus.name, marker: marker(), id: "THE-ONE"), entry("Unrelated", marker: nil)])
        host.output = Data("Work".utf8)
        let result = try focus.run(["on": .bool(true)], host: host)
        XCTAssertEqual(result.output, Data("Work".utf8))
        XCTAssertEqual(host.runs.count, 1)
        // Run by identifier: the exact shortcut the check found.
        XCTAssertEqual(host.runs[0].name, "THE-ONE")
        XCTAssertEqual(host.runs[0].input, Data(#"{"on":true}"#.utf8))
        XCTAssertEqual(host.runs[0].patience, 3)
        XCTAssertEqual(host.outputTypes, ["public.plain-text"], "text output is asked for as plain text")
        XCTAssertEqual(host.runs[0].timeout, 20)
    }

    // MARK: - Copies

    func testShortcutsKeepBothCopiesAreDuplicatesWithTheOneToDeleteNamed() {
        let copy = entry("settings · Set Focus 1", marker: nil, id: "COPY")
        let real = entry("settings · Set Focus", marker: marker(), id: "REAL")
        let status = HelperAssessment.status(of: focus, in: [copy, real])
        XCTAssertEqual(status.state, .duplicated)
        XCTAssertEqual(status.copies.map(\.id), ["REAL", "COPY"])
        XCTAssertEqual(status.copies.map(\.keep), [true, false])
        XCTAssertEqual(status.remedy, "in Shortcuts, delete \"settings · Set Focus 1\" and keep \"settings · Set Focus\"")
        // The keeper is exactly this helper, current: it runs, by its identifier; the copy never does.
        XCTAssertTrue(status.isRunnable)
        XCTAssertEqual(status.shortcutIDs.first, "REAL")
        let host = FakeHost([copy, real])
        _ = try? focus.run(["on": .bool(true)], host: host)
        XCTAssertEqual(host.runs.map(\.name), ["REAL"])
        // An old keeper does not run.
        let oldReal = entry("settings · Set Focus", marker: marker(version: 1), id: "OLD")
        XCTAssertFalse(HelperAssessment.status(of: focus, in: [copy, oldReal]).isRunnable)
        // Two marked copies, neither under the exact name: keep the current one and rename it.
        let a = InstalledShortcut(id: "A", name: "settings · Set Focus 1", marker: marker(version: 1), modified: Date(timeIntervalSince1970: 10))
        let b = InstalledShortcut(id: "B", name: "settings · Set Focus 2", marker: marker(), modified: Date(timeIntervalSince1970: 5))
        let both = HelperAssessment.status(of: focus, in: [a, b])
        XCTAssertEqual(both.copies.first?.id, "B")
        XCTAssertEqual(both.remedy, "in Shortcuts, delete \"settings · Set Focus 1\" and keep \"settings · Set Focus 2\", then rename \"settings · Set Focus 2\" to \"settings · Set Focus\"")
        // The marked copy beats an unmarked one that has the exact name.
        let handMade = entry("settings · Set Focus", marker: nil, id: "HAND")
        let markedCopy = entry("settings · Set Focus 1", marker: marker(), id: "MARKED")
        XCTAssertEqual(HelperAssessment.status(of: focus, in: [handMade, markedCopy]).copies.first?.id, "MARKED")
        // Same rank: the newer is kept.
        let c = InstalledShortcut(id: "C", name: "settings · Set Focus 1", marker: nil, modified: Date(timeIntervalSince1970: 1))
        let d = InstalledShortcut(id: "D", name: "settings · Set Focus 2", marker: nil, modified: Date(timeIntervalSince1970: 9))
        XCTAssertEqual(HelperAssessment.status(of: focus, in: [c, d]).copies.first?.id, "D")
    }

    func testOnlyANumberedSuffixMakesACopy() {
        XCTAssertTrue(HelperAssessment.isCopy("settings · Set Focus 1", of: focus.name))
        XCTAssertTrue(HelperAssessment.isCopy("Settings · set focus 12", of: focus.name))
        XCTAssertFalse(HelperAssessment.isCopy("settings · Set Focus", of: focus.name))
        XCTAssertFalse(HelperAssessment.isCopy("settings · Set Focus Now", of: focus.name))
        XCTAssertFalse(HelperAssessment.isCopy("settings · Set Focus1", of: focus.name))
        XCTAssertFalse(HelperAssessment.isCopy("settings · Set Focus ", of: focus.name))
        XCTAssertEqual(HelperAssessment.status(of: focus, in: [entry("settings · Set Focus Now", marker: nil)]).state, .missing)
    }

    // MARK: - Installing

    func testInstallOpensEachHelperThatNeedsItExactlyOnce() throws {
        let get = Helper(id: "settings.get", tool: "settings", title: "Get", description: "d", version: 1, steps: [RecipeStep(action: "x")])
        let set = Helper(id: "settings.set", tool: "settings", title: "Set", description: "d", version: 1, steps: [RecipeStep(action: "y")])
        let fine = Helper(id: "settings.fine", tool: "settings", title: "Fine", description: "d", version: 1, steps: [RecipeStep(action: "z")])
        let host = FakeHost([entry(fine.name, marker: fine.marker)])
        var polls = 0
        host.onList = { host in
            polls += 1
            // The person clicks Add on both after a few polls.
            if polls == 4 { host.library += [self.entry(get.name, marker: get.marker), self.entry(set.name, marker: set.marker)] }
        }
        let catalogue = HelperCatalogue(helpers: [get, set, fine])
        var announced: [String] = []
        let result = try catalogue.install([get, set, fine], timeout: 5, interval: 0.01, host: host) { announced.append($0.id) }
        XCTAssertEqual(host.offered.count, 2)
        XCTAssertEqual(Set(host.offered.map(\.lastPathComponent)), ["settings · Get.shortcut", "settings · Set.shortcut"])
        XCTAssertEqual(announced, ["settings.get", "settings.set"])
        XCTAssertEqual(result.offered.map(\.id), ["settings.get", "settings.set"])
        XCTAssertEqual(result.statuses.map(\.state), [.current, .current, .current])
    }

    func testInstallNeverReoffersWhileWaitingAndLeavesDuplicatesToAPerson() throws {
        let host = FakeHost([entry(focus.name, marker: marker()), entry(focus.name + " 1", marker: nil)])
        let result = try catalogue.install([focus], timeout: 0.05, interval: 0.01, host: host)
        XCTAssertEqual(host.offered, [])
        XCTAssertEqual(result.statuses.first?.state, .duplicated)
        let missing = FakeHost()
        _ = try catalogue.install([focus], timeout: 0.05, interval: 0.01, host: missing)
        XCTAssertEqual(missing.offered.count, 1)
    }

    func testOfferWritesTheMarkedRecipeIntoTheToolsFolderAndOpensIt() throws {
        let host = FakeHost()
        let file = try focus.offer(host: host)
        XCTAssertEqual(host.written, [focus.recipe])
        XCTAssertEqual(host.offered, [file])
        XCTAssertTrue(file.path.hasSuffix("Library/Application Support/settings/shortcuts/settings · Set Focus.shortcut"))
    }

    func testWaitingEndsWhenThePersonHasAddedIt() throws {
        let host = FakeHost()
        var polls = 0
        let current = entry(focus.name, marker: marker())
        host.onList = { host in
            polls += 1
            if polls == 3 { host.library = [current] }
        }
        let status = try focus.waitUntilInstalled(timeout: 5, interval: 0.01, host: host)
        XCTAssertEqual(status.state, .current)
        XCTAssertEqual(polls, 3)
    }

    func testWaitingGivesUpWithTheStateAsItStands() throws {
        let host = FakeHost([entry(focus.name, marker: marker(version: 1))])
        let status = try focus.waitUntilInstalled(timeout: 0.05, interval: 0.01, host: host)
        XCTAssertEqual(status.state, .outdated)
    }

    // MARK: - Stale and census

    func testCensusReportsHelpersReplacedNamesAndOrphans() throws {
        let host = FakeHost([
            entry(focus.name, marker: marker(version: 1), id: "F"),
            entry("settings dnd", marker: nil, id: "OLD"),
            entry("browse · Tabs", marker: marker(id: "browse.tabs"), id: "ORPHAN"),
            entry("settings · Retired", marker: marker(id: "settings.retired"), id: "RETIRED"),
            entry("Mine", marker: nil, id: "MINE"),
        ])
        let rows = try catalogue.census(host: host)
        XCTAssertEqual(rows.map(\.name), ["browse · Tabs", "settings dnd", "settings · Retired", "settings · Set Focus"])
        XCTAssertEqual(rows.map(\.state), [.unclaimed, .obsolete, .unclaimed, .outdated])
        XCTAssertEqual(rows.map(\.tool), ["browse", "settings", "settings", "settings"])
        XCTAssertFalse(rows.contains { $0.shortcutIDs.contains("MINE") })
        let stale = try catalogue.stale(for: "settings", host: host)
        XCTAssertEqual(Set(stale.flatMap(\.shortcutIDs)), ["OLD", "RETIRED"])
    }

    func testACensusOfAnEmptyLibraryListsEveryHelperAsMissing() throws {
        XCTAssertEqual(try catalogue.census(host: FakeHost()).map(\.state), [.missing])
    }

    // MARK: - The library scan

    func testTheScanReadsMarkersRunsAndDatesAndSkipsDeletedShortcuts() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("helpers-library-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &db), SQLITE_OK)
        func exec(_ sql: String) { XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK, sql) }
        exec("""
            create table ZSHORTCUT (Z_PK integer primary key, ZWORKFLOWID varchar, ZNAME varchar, ZTOMBSTONED integer,
              ZRUNEVENTSCOUNT integer, ZLASTRUNEVENTDATE timestamp, ZMODIFICATIONDATE timestamp, ZNOINPUTBEHAVIORDATA blob);
            create table ZSHORTCUTACTIONS (Z_PK integer primary key, ZSHORTCUT integer, ZDATA blob);
            insert into ZSHORTCUT values (1, 'ID-1', 'settings · Set Focus', 0, 3, 100.5, 50, null);
            insert into ZSHORTCUT values (2, 'ID-2', 'Mine', null, 0, null, null, null);
            insert into ZSHORTCUT values (3, 'ID-3', 'Deleted', 1, 0, null, null, null);
            """)
        let actions = focus.recipe.actions.map { step -> [String: Any] in
            ["WFWorkflowActionIdentifier": step.action,
             "WFWorkflowActionParameters": step.parameters.mapValues { PlistValueCoding.object($0) }]
        }
        let blob = try PropertyListSerialization.data(fromPropertyList: actions, format: .binary, options: 0)
        var statement: OpaquePointer?
        sqlite3_prepare_v2(db, "insert into ZSHORTCUTACTIONS values (1, 1, ?)", -1, &statement, nil)
        _ = blob.withUnsafeBytes { sqlite3_bind_blob(statement, 1, $0.baseAddress, Int32(blob.count), nil) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
        sqlite3_finalize(statement)
        // The no-input behaviour as WorkflowKit serialises it: {Name, Parameters}.
        let behaviour = try PropertyListSerialization.data(fromPropertyList: RecipeEncoding.noInputBehavior("stop"), format: .binary, options: 0)
        sqlite3_prepare_v2(db, "update ZSHORTCUT set ZNOINPUTBEHAVIORDATA = ? where Z_PK = 1", -1, &statement, nil)
        _ = behaviour.withUnsafeBytes { sqlite3_bind_blob(statement, 1, $0.baseAddress, Int32(behaviour.count), nil) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
        sqlite3_finalize(statement)
        sqlite3_close(db)

        let found = try ShortcutLibrary(databasePath: path).installed()
        XCTAssertEqual(found.map(\.name), ["Mine", "settings · Set Focus"])
        let helper = try XCTUnwrap(found.last)
        XCTAssertEqual(helper.marker, focus.marker)
        XCTAssertEqual(helper.runCount, 3)
        XCTAssertEqual(helper.lastRun, Date(timeIntervalSinceReferenceDate: 100.5))
        XCTAssertEqual(helper.modified, Date(timeIntervalSinceReferenceDate: 50))
        XCTAssertNil(found.first?.marker)
        XCTAssertNil(found.first?.lastRun)
        XCTAssertEqual(helper.noInputBehavior, "WFWorkflowNoInputBehaviorShowError")
        XCTAssertNil(found.first?.noInputBehavior)
        XCTAssertEqual(HelperAssessment.status(of: focus, in: found).state, .current)
    }
}

final class NamedVariableTests: XCTestCase {

    func testNamedVariablesAreTokens() {
        XCTAssertEqual(Tokens.segments("${focusName}"), [.variable("focusName")])
        XCTAssertEqual(Tokens.segments("a ${x_1} b"), [.text("a "), .variable("x_1"), .text(" b")])
        XCTAssertEqual(Tokens.segments("${not ok}"), [.text("${not ok}")])
        XCTAssertEqual(Tokens.segments("${}"), [.text("${}")])
        XCTAssertEqual(Tokens.segments("$${x}"), [.text("${x}")])
        XCTAssertEqual(Tokens.segments("${open"), [.text("${open")])
    }

    func testANamedVariableEncodesAsAgendasHandWrittenOne() throws {
        // agenda's tag helper wrote this by hand, and Shortcuts ran it.
        let written: [String: Any] = ["Value": ["Type": "Variable", "VariableName": "agendaTags"],
                                      "WFSerializationType": "WFTextTokenAttachment"]
        let encoded = Tokens.encode("${agendaTags}", isTextParameter: false, previous: nil)
        XCTAssertEqual(encoded as? NSDictionary, written as NSDictionary)
        let text = try XCTUnwrap(Tokens.encode("is ${x}", isTextParameter: true, previous: nil) as? [String: Any])
        let value = try XCTUnwrap(text["Value"] as? [String: Any])
        XCTAssertEqual(value["string"] as? String, "is \u{FFFC}")
        XCTAssertEqual((value["attachmentsByRange"] as? [String: Any])?["{3, 1}"] as? NSDictionary,
                       ["Type": "Variable", "VariableName": "x"] as NSDictionary)
    }

    func testAVariableNestedInADictionaryBecomesAnAttachmentAndOtherStringsStay() throws {
        let value = PlistValue.dictionary(["Type": .string("Variable"), "Variable": .string("${until}"),
                                           "List": .array([.string("$input"), .string("plain $5")])])
        let nested = try XCTUnwrap(RecipeEncoding.nested(value, previous: nil) as? [String: Any])
        XCTAssertEqual(nested["Type"] as? String, "Variable")
        XCTAssertEqual((nested["Variable"] as? [String: Any])?["WFSerializationType"] as? String, "WFTextTokenAttachment")
        let list = try XCTUnwrap(nested["List"] as? [Any])
        XCTAssertEqual(((list[0] as? [String: Any])?["Value"] as? [String: Any])?["Type"] as? String, "ExtensionInput")
        XCTAssertEqual(list[1] as? String, "plain $5")
        XCTAssertTrue(RecipeEncoding.usesInputAnywhere(value))
        XCTAssertFalse(RecipeEncoding.usesInputAnywhere(.dictionary(["a": .string("${x}")])))
    }

    func testIfIsKnownThoughTheCatalogueLeavesItOut() throws {
        let catalog: ActionCatalog
        do { catalog = try ActionCatalog() } catch { throw XCTSkip("no action catalogue on this Mac") }
        XCTAssertThrowsError(try catalog.action(id: "is.workflow.actions.conditional"))
        let recipe = Recipe(name: "If probe", actions: [
            RecipeStep(action: "is.workflow.actions.conditional",
                       parameters: ["GroupingIdentifier": .string("G"), "WFControlFlowMode": .integer(0),
                                    "WFCondition": .integer(100), "WFInput": .dictionary(["Type": .string("Variable"), "Variable": .string("$input")])]),
            RecipeStep(action: "is.workflow.actions.conditional",
                       parameters: ["GroupingIdentifier": .string("G"), "WFControlFlowMode": .integer(2)]),
        ])
        XCTAssertNoThrow(try ShortcutBuilder(catalog: catalog).build(recipe))
        let typo = Recipe(name: "x", actions: [RecipeStep(action: "is.workflow.actions.conditional", parameters: ["WFCondtion": .integer(4)])])
        XCTAssertThrowsError(try ShortcutBuilder(catalog: catalog).build(typo))
    }
}
