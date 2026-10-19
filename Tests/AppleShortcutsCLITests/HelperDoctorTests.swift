//
//  HelperDoctorTests.swift
//  AppleShortcutsCLI
//
//  Created by David Sherlock on 2026.
//

import AppleShortcuts
import ArgumentParser
import CLIKit
import XCTest
@testable import AppleShortcutsCLI

final class DoctorHost: HelperHost, @unchecked Sendable {
    var library: [InstalledShortcut]
    var offered: [URL] = []
    var onList: ((DoctorHost) -> Void)?
    init(_ library: [InstalledShortcut]) { self.library = library }
    func installed() throws -> [InstalledShortcut] { onList?(self); return library }
    func write(_ recipe: Recipe, to folder: URL) throws -> URL { folder.appendingPathComponent(recipe.name + ".shortcut") }
    func offer(_ file: URL) throws { offered.append(file) }
    func run(_ name: String, input: Data?, patience: Double, timeout: Double, onWaiting: (@Sendable () -> Void)?) throws -> RunResult {
        RunResult(output: Data(), duration: 0)
    }
}

final class HelperDoctorTests: XCTestCase {

    func helper(_ what: String, tool: String = "notes", replaces: [String] = []) -> Helper {
        Helper(id: "\(tool).\(what)", tool: tool, title: what.capitalized, description: "d", version: 1,
               steps: [RecipeStep(action: "is.workflow.actions.nothing")], replaces: replaces)
    }

    func installed(_ helper: Helper, id: String = UUID().uuidString) -> InstalledShortcut {
        InstalledShortcut(id: id, name: helper.name, marker: helper.marker)
    }

    func testAReportListsTheToolsHelpersAndItsStaleOnesAndExitsThreeWhileAnyIsMissing() throws {
        let tag = helper("tag", replaces: ["notes tagger"])
        let pin = helper("pin")
        let other = helper("focus", tool: "settings")
        let catalogue = HelperCatalogue(helpers: [tag, pin, other])
        let host = DoctorHost([installed(tag), InstalledShortcut(id: "OLD", name: "notes tagger")])
        let report = try HelperDoctor.run(tool: "notes", catalogue: catalogue, install: false, wait: 0, host: host)
        XCTAssertEqual(report.rows.map(\.state), [.missing, .current, .obsolete])
        XCTAssertEqual(report.rows.map(\.id), ["notes.pin", "notes.tag", "notes.tag"])
        XCTAssertEqual(report.error?.code, .authRequired)
        XCTAssertEqual(report.error?.retry, .notStarted)
        XCTAssertTrue(report.error?.message.contains("notes · Pin (not installed)") == true)
        XCTAssertTrue(host.offered.isEmpty)
    }

    func testInstallOffersOnlyWhatIsNeededOnceAndAReadyReportHasNoError() throws {
        let tag = helper("tag")
        let pin = helper("pin")
        let catalogue = HelperCatalogue(helpers: [tag, pin])
        let host = DoctorHost([installed(tag)])
        var polls = 0
        host.onList = { host in
            polls += 1
            if polls == 3 { host.library.append(self.installed(pin)) }
        }
        var announced: [String] = []
        let report = try HelperDoctor.run(tool: "notes", catalogue: catalogue, install: true, wait: 5, host: host, interval: 0.01) {
            announced.append($0.id)
        }
        XCTAssertEqual(host.offered.count, 1)
        XCTAssertEqual(announced, ["notes.pin"])
        XCTAssertEqual(report.offered.map(\.id), ["notes.pin"])
        XCTAssertNil(report.error)
        XCTAssertEqual(report.rows.map(\.state), [.current, .current])
    }

    func testRowsShowTheInstalledNameAndCopies() {
        let row = HelperDoctorRow(HelperStatus(id: "notes.pin", name: "notes · Pin", tool: "notes", state: .misnamed,
                                               installedName: "notes · Pin 1"))
        XCTAssertEqual(row.name, "notes · Pin 1")
        XCTAssertEqual(row.tableRow.first, "notes · Pin 1")
        XCTAssertTrue(row.renderText().hasPrefix("✗ notes · Pin 1"))
    }

    func testHelperRefusalsExitAsSetupStepsUsageOrBrokenBuilds() {
        let status = HelperStatus(id: "notes.pin", name: "notes · Pin", tool: "notes", state: .outdated, install: "notes doctor --install")
        XCTAssertEqual(HelperError.notReady(status).cliError.code, .authRequired)
        XCTAssertEqual(HelperError.notReady(status).cliError.hint, "notes doctor --install, then click Add Shortcut and choose Replace")
        XCTAssertEqual(HelperError.invalidInput(id: "a.b", reason: "x").cliError.code, .usage)
        XCTAssertEqual(HelperError.invalidCatalogue("x").cliError.code, .upstream)
    }

    func testTheDoctorDeclaresItsEffectByWhetherItInstalls() throws {
        enum Tool: HelperTool { static let toolName = "notes" }
        XCTAssertEqual(HelperDoctorCommand<Tool>.commandEffect, .acting(destructive: false, idempotent: true))
        XCTAssertFalse(try HelperDoctorCommand<Tool>.parse([]).actsThisRun)
        XCTAssertTrue(try HelperDoctorCommand<Tool>.parse(["--install"]).actsThisRun)
        XCTAssertEqual(HelperDoctorCommand<Tool>.configuration.commandName, "doctor")
    }
}

final class HelperErrorServiceTests: XCTestCase {
    func testTheErrorIsTaggedWithTheOwningTool() {
        let status = HelperStatus(id: "ask.pcc", name: "ask · Private Cloud Compute", tool: "ask", state: .missing)
        XCTAssertEqual(HelperError.notReady(status).cliError.service, "ask")
        XCTAssertEqual(HelperError.invalidInput(id: "notes.change", reason: "x").cliError.service, "notes")
    }
}

final class BrokenHelperExitTests: XCTestCase {
    func testABrokenHelperExitsFiveNotThree() {
        let broken = HelperStatus(id: "mac.alarms", name: "mac · Alarms", tool: "mac", state: .broken, problems: ["step 9: x"])
        XCTAssertEqual(HelperError.notReady(broken).cliError.code, .upstream)
        XCTAssertEqual(HelperError.notReady(broken).cliError.retry, .notStarted)
    }
}
