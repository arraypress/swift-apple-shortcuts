//
//  HelperDoctorCommand.swift
//  AppleShortcutsCLI
//
//  Created by David Sherlock on 2026.
//
//  `<tool> doctor [--install]`, once for the whole fleet: which of the tool's
//  helper shortcuts are installed, and offering the ones that are not.
//

import AppleShortcuts
import ArgumentParser
import CLIKit
import Foundation

/// The tool a doctor reports on.
public protocol HelperTool {
    /// `settings`, `notes`.
    static var toolName: String { get }
}

/// `<tool> doctor [--install] [--wait <s>]`.
///
/// ```swift
/// enum NotesHelpers: HelperTool { static let toolName = "notes" }
/// typealias DoctorCommand = HelperDoctorCommand<NotesHelpers>
/// ```
public struct HelperDoctorCommand<Tool: HelperTool>: CLICommand, ConditionallyActing {

    public static var serviceID: String { Tool.toolName }

    /// Reads, unless --install offers helpers (which adds nothing without a click).
    public static var commandEffect: CommandEffect { .acting(destructive: false, idempotent: true) }

    public var actsThisRun: Bool { install }

    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "doctor",
            abstract: "Check the helper shortcuts \(Tool.toolName) uses; --install offers the missing or outdated ones.",
            discussion: """
                  \(Tool.toolName) doctor              # each helper: installed, missing, out of date
                  \(Tool.toolName) doctor --install    # Shortcuts shows one Add sheet per helper needed

                Some of what \(Tool.toolName) does only a Shortcuts action can do, so it ships \
                helper shortcuts named "\(Tool.toolName) · …", on a grey tile, each with a comment \
                at the top saying what it does. Adding one takes your click: --install opens each \
                needed helper in Shortcuts ONCE and waits (up to --wait seconds) until it is in \
                your library. Replacing an old version: choose Replace. A helper that answers back \
                may ask once "Allow … to output?" — choose Always Allow. A helper with two copies \
                is never offered again: delete the copy the report names. Exit 3 while any helper \
                is missing, out of date or duplicated.
                """
        )
    }

    @Flag(name: .long, help: "Offer each helper that is missing or out of date.")
    public var install = false

    @Option(name: .long, help: ArgumentHelp("With --install: seconds to wait for your clicks.", valueName: "seconds"))
    public var wait: Double = 180

    @OptionGroup public var common: CommonOptions

    public init() {}

    public func execute() async throws {
        let catalogue = try HelperCatalogue.builtIn()
        let report = try HelperDoctor.run(tool: Tool.toolName, catalogue: catalogue, install: install, wait: wait) { helper in
            if !common.quiet { Terminal.writeError("\(Tool.toolName): offered \"\(helper.name)\" — click Add Shortcut (Replace if asked)") }
        }
        try common.emitter.emitAll(report.rows.map(HelperDoctorRow.init))
        if let error = report.error { throw error }
    }
}

/// The doctor's rules, apart from the command so they can be tested on a fake.
public enum HelperDoctor {

    /// What a doctor run found.
    public struct Report {
        public let rows: [HelperStatus]
        public let offered: [Helper]
        /// Exit 3 when anything still needs doing.
        public let error: CLIError?
    }

    public static func run(tool: String, catalogue: HelperCatalogue, install: Bool, wait: Double,
                           host: any HelperHost = LiveHelperHost(), interval: Double = 1,
                           onOffered: (Helper) -> Void = { _ in }) throws -> Report {
        let helpers = catalogue.helpers(for: tool)
        var rows: [HelperStatus]
        var offered: [Helper] = []
        if install {
            let result = try catalogue.install(helpers, timeout: wait, interval: interval, host: host, onOffered: onOffered)
            rows = result.statuses
            offered = result.offered
        } else {
            let library = try host.installed()
            rows = helpers.map { HelperAssessmentAccess.status($0, library) }
        }
        let stale = try catalogue.stale(for: tool, host: host)
        let blocking = rows.filter { !$0.isRunnable }
        let error = blocking.isEmpty ? nil : CLIError(
            code: .authRequired,
            message: "\(blocking.count) helper\(blocking.count == 1 ? "" : "s") not ready: "
                + blocking.map { "\($0.name) (\($0.summary))" }.joined(separator: "; "),
            hint: blocking.compactMap(\.remedy).first ?? "\(tool) doctor --install, then click Add Shortcut",
            service: tool, retry: .notStarted)
        return Report(rows: rows + stale, offered: offered, error: error)
    }
}

/// Status without going back to the library for each helper.
enum HelperAssessmentAccess {
    static func status(_ helper: Helper, _ library: [InstalledShortcut]) -> HelperStatus {
        let host = Snapshot(library: library)
        return (try? helper.status(host: host)) ?? HelperStatus(id: helper.id, name: helper.name, tool: helper.tool, state: .missing)
    }

    /// A host that answers `installed()` from a list already read.
    struct Snapshot: HelperHost {
        let library: [InstalledShortcut]
        func installed() throws -> [InstalledShortcut] { library }
        func write(_ recipe: Recipe, to folder: URL) throws -> URL { throw ShortcutsError.unavailable("read-only snapshot") }
        func offer(_ file: URL) throws { throw ShortcutsError.unavailable("read-only snapshot") }
        func run(_ name: String, input: Data?, patience: Double, timeout: Double, onWaiting: (@Sendable () -> Void)?) throws -> RunResult {
            throw ShortcutsError.unavailable("read-only snapshot")
        }
    }
}

/// One helper, as a doctor row.
public struct HelperDoctorRow: Encodable, TableRenderable {
    public let id: String
    public let name: String
    public let state: HelperState
    public let summary: String
    public let remedy: String?
    public let copies: [HelperCopy]

    public init(_ status: HelperStatus) {
        id = status.id
        name = status.installedName ?? status.name
        state = status.state
        summary = status.summary
        remedy = status.remedy
        copies = status.copies
    }

    public static let tableColumns = ["HELPER", "STATE", "TO FIX"]
    public var tableRow: [String] { [name, summary, remedy ?? "—"] }
    public static let flexibleColumns = [0, 2]

    public func renderText() -> String {
        "\(state == .current ? "✓" : "✗") \(name)  \(summary)" + (remedy.map { "\n    \($0)" } ?? "")
    }
}

/// A helper that is missing or out of date is a setup step (3), with the
/// command that fixes it; bad input to one is a usage error (2); a broken
/// catalogue is a broken build (5). Nothing ran in any of them.
extension HelperError: CLIErrorDescribing {
    public var cliError: CLIError {
        let message = errorDescription ?? String(describing: self)
        switch self {
        case .notReady(let status) where status.state == .broken:
            // Not a setup step: the helper as shipped is wrong. 5, and nothing ran.
            return CLIError(code: .upstream, message: message, hint: remedy, service: status.tool, retry: .notStarted)
        case .notReady(let status):
            return CLIError(code: .authRequired, message: message, hint: remedy, service: status.tool, retry: .notStarted)
        case .invalidInput(let id, _):
            return CLIError(code: .usage, message: message, service: String(id.prefix { $0 != "." }), retry: .notStarted)
        case .invalidCatalogue:
            return CLIError(code: .upstream, message: message, hint: "reinstall the tool", service: "shortcuts", retry: .notStarted)
        }
    }
}
