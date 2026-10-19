//
//  HelperLintTests.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  The round-trip lint, on step lists shaped like what Shortcuts stored for
//  the helpers the Mac editor showed broken, and on ones it ran.
//

import XCTest
@testable import AppleShortcuts

final class HelperLintTests: XCTestCase {

    func variable(_ name: String) -> PlistValue {
        .dictionary(["Value": .dictionary(["Type": .string("Variable"), "VariableName": .string(name)]),
                     "WFSerializationType": .string("WFTextTokenAttachment")])
    }
    func set(_ name: String) -> ShortcutStep {
        ShortcutStep(action: "is.workflow.actions.setvariable", parameters: ["WFVariableName": .string(name), "WFInput": .string("x")])
    }
    func ifStep(_ condition: Int, on name: String, text: String? = nil) -> ShortcutStep {
        var parameters: [String: PlistValue] = ["GroupingIdentifier": .string("G"), "WFControlFlowMode": .integer(0),
                                                "WFCondition": .integer(condition),
                                                "WFInput": .dictionary(["Type": .string("Variable"), "Variable": variable(name)])]
        if let text { parameters["WFConditionalActionString"] = .string(text) }
        return ShortcutStep(action: "is.workflow.actions.conditional", parameters: parameters)
    }

    /// As stored for "settings · Set System Setting" v1: If sysSetting is "low-power".
    func testAnIfComparingTextIsBroken() {
        let problems = HelperLint.problems([set("sysSetting"), ifStep(4, on: "sysSetting", text: "low-power")])
        XCTAssertEqual(problems, ["step 2 (is.workflow.actions.conditional): an If comparing text loses its text on the Mac (use \"has any value\" with one key per branch)"])
        for condition in [5, 8, 9, 99, 999] {
            XCTAssertFalse(HelperLint.problems([set("v"), ifStep(condition, on: "v", text: "x")]).isEmpty, "\(condition)")
        }
    }

    /// As stored for "settings · Set Focus": If focusUntil has any value — it ran.
    func testHasAnyValueIsFine() {
        XCTAssertEqual(HelperLint.problems([set("focusUntil"), ifStep(100, on: "focusUntil"), ifStep(101, on: "focusUntil")]), [])
        let otherwise = ShortcutStep(action: "is.workflow.actions.conditional", parameters: ["GroupingIdentifier": .string("G"), "WFControlFlowMode": .integer(1)])
        XCTAssertEqual(HelperLint.problems([otherwise]), [])
    }

    func testAnIfWithNothingToTestIsBroken() {
        let bare = ShortcutStep(action: "is.workflow.actions.conditional", parameters: ["WFControlFlowMode": .integer(0), "WFCondition": .integer(100)])
        XCTAssertEqual(HelperLint.problems([bare]), ["step 1 (is.workflow.actions.conditional): an If with nothing to test"])
    }

    /// As stored for "mac · Start Timer" v1: "Start timer for Unknown Variable minutes".
    func testAVariableInAQuantityIsBroken() {
        let timer = ShortcutStep(action: "is.workflow.actions.timer.start", parameters: [
            "WFDuration": .dictionary(["Value": .dictionary(["Magnitude": variable("tmMinutes"), "Unit": .string("min")]),
                                       "WFSerializationType": .string("WFQuantityFieldValue")])])
        XCTAssertEqual(HelperLint.problems([set("tmMinutes"), timer]),
                       ["step 2 (is.workflow.actions.timer.start): a variable inside a quantity shows as Unknown Variable on the Mac"])
        let fixed = ShortcutStep(action: "is.workflow.actions.timer.start", parameters: [
            "WFDuration": .dictionary(["Value": .dictionary(["Magnitude": .integer(10), "Unit": .string("min")]),
                                       "WFSerializationType": .string("WFQuantityFieldValue")])])
        XCTAssertEqual(HelperLint.problems([fixed]), [])
    }

    func testAVariableUsedBeforeItIsSetIsDangling() {
        let use = ShortcutStep(action: "is.workflow.actions.gettext", parameters: ["WFTextActionText": variable("later")])
        XCTAssertEqual(HelperLint.problems([use, set("later")]),
                       ["step 1 (is.workflow.actions.gettext): uses the variable later before any Set Variable names it"])
        XCTAssertEqual(HelperLint.problems([set("later"), use]), [])
        // Deep inside a filter's token string too.
        let filter = ShortcutStep(action: "is.workflow.actions.filter.notes", parameters: ["WFContentItemFilter": .dictionary([
            "Value": .dictionary(["WFActionParameterFilterTemplates": .array([.dictionary(["Values": .dictionary(["String": .dictionary([
                "Value": .dictionary(["attachmentsByRange": .dictionary(["{0, 1}": .dictionary(["Type": .string("Variable"), "VariableName": .string("noteTitle")])])])])])])])])])])
        XCTAssertEqual(HelperLint.problems([filter]).count, 1)
        XCTAssertEqual(HelperLint.variableNames(in: .dictionary(filter.parameters)), ["noteTitle"])
    }

    func testABuiltHelperIsLintedAsItWouldBeStoredAndAFailingOneIsRefusedByTheCatalogue() throws {
        let broken = Helper(id: "mac.timer", tool: "mac", title: "Timer", description: "d", version: 1, steps: [
            RecipeStep(action: "is.workflow.actions.detect.dictionary", parameters: ["WFInput": .string("$input")]),
            RecipeStep(action: "is.workflow.actions.setvariable", parameters: ["WFVariableName": .string("m"), "WFInput": .string("$previous")]),
            RecipeStep(action: "is.workflow.actions.timer.start", parameters: ["WFDuration": .dictionary([
                "Value": .dictionary(["Magnitude": .string("${m}"), "Unit": .string("min")]), "WFSerializationType": .string("WFQuantityFieldValue")])]),
        ])
        XCTAssertEqual(HelperLint.problems(of: broken).count, 1)
        XCTAssertTrue(HelperCatalogueCheck.problems(HelperCatalogue(helpers: [broken])).contains { $0.contains("Unknown Variable") })
        let shipped = try HelperCatalogue.builtIn().helpers
        XCTAssertEqual(shipped.filter { !$0.experimental }.flatMap(HelperLint.problems(of:)), [])
        // An experimental helper is allowed its failing lint — and only it.
        XCTAssertTrue(shipped.filter(\.experimental).allSatisfy { !HelperLint.problems(of: $0).isEmpty })
    }

    func testABrokenInstalledHelperIsNeverRunnable() throws {
        let helper = Helper(id: "settings.focus", tool: "settings", title: "Set Focus", description: "d", version: 1,
                            steps: [RecipeStep(action: "is.workflow.actions.nothing")])
        let entry = InstalledShortcut(id: "X", name: helper.name, marker: helper.marker, problems: ["step 2: an If comparing text …"])
        let status = HelperAssessment.status(of: helper, in: [entry])
        XCTAssertEqual(status.state, .broken)
        XCTAssertFalse(status.isRunnable)
        XCTAssertTrue(status.summary.hasPrefix("BROKEN — step 2"))
        XCTAssertNotNil(status.remedy)
        let host = FakeHost([entry])
        XCTAssertThrowsError(try helper.run(host: host))
        XCTAssertTrue(host.runs.isEmpty)
        // An outdated copy is reported as outdated first: the reinstall is the fix.
        let old = InstalledShortcut(id: "X", name: helper.name, marker: HelperMarker(id: helper.id, version: 0, recipe: "00000000"), problems: ["x"])
        XCTAssertEqual(HelperAssessment.status(of: helper, in: [old]).state, .outdated)
    }

    func testAnAskEachTimeParameterIsBroken() {
        let ask = ShortcutStep(action: "is.workflow.actions.timer.start", parameters: ["WFDuration": .dictionary(["Value": .dictionary(["Type": .string("Ask")]), "WFSerializationType": .string("WFTextTokenAttachment")])])
        XCTAssertEqual(HelperLint.problems([ask]), ["step 1 (is.workflow.actions.timer.start): a parameter is Ask Each Time — a background run would wait on a person"])
        XCTAssertEqual(HelperLint.noInputBehaviorName(try! PropertyListSerialization.data(fromPropertyList: ["Name": "X"], format: .binary, options: 0)), "X")
        XCTAssertNil(HelperLint.noInputBehaviorName(Data("junk".utf8)))
    }

    func testNothingIsShownAndNothingWaits() {
        let show = ShortcutStep(action: "is.workflow.actions.showresult", parameters: [:])
        XCTAssertEqual(HelperLint.problems([show]).count, 1)
        let followUp = ShortcutStep(action: "is.workflow.actions.askllm", parameters: ["FollowUp": .bool(true)])
        XCTAssertTrue(HelperLint.problems([followUp]).first?.contains("FollowUp is on") == true)
        XCTAssertEqual(HelperLint.problems([ShortcutStep(action: "is.workflow.actions.askllm", parameters: ["FollowUp": .bool(false)])]), [])
        let shown = ShortcutStep(action: "is.workflow.actions.output", parameters: ["WFOutput": .string("x")])
        XCTAssertTrue(HelperLint.problems([shown]).first?.contains("Do Nothing") == true)
        let quiet = ShortcutStep(action: "is.workflow.actions.output", parameters: ["WFOutput": .string("x"), "WFNoOutputSurfaceBehavior": .string("Do Nothing")])
        XCTAssertEqual(HelperLint.problems([quiet]), [])
        let open = ShortcutStep(action: "com.apple.Notes.CreateTagLinkAction", parameters: ["OpenWhenRun": .bool(true)])
        XCTAssertEqual(HelperLint.problems([open]).count, 1)
    }

    func testAnAnsweringHelperMustEndWithAQuietStopAndOutput() {
        let answer = Helper(id: "ask.x", tool: "ask", title: "X", description: "d", version: 1, icon: HelperIcon(glyph: 61581, color: "purple"),
                            output: HelperOutput(type: .text), steps: [RecipeStep(action: "is.workflow.actions.askllm")])
        XCTAssertTrue(HelperCatalogueCheck.problems(HelperCatalogue(helpers: [answer])).contains { $0.contains("ends with Stop and Output") })
    }

    func testAHelperThatActsOnFoundItemsMustHaveACheckMode() throws {
        let filter = PlistValue.dictionary(["Value": .dictionary([:]), "WFSerializationType": .string("WFContentPredicateTableTemplate")])
        let unsafe = Helper(id: "notes.pin", tool: "notes", title: "Pin", description: "d", version: 1, icon: HelperIcon(glyph: 61465, color: "yellow"),
                            input: [HelperField(name: "title", type: .string, description: "")],
                            steps: [RecipeStep(action: "is.workflow.actions.filter.notes", parameters: ["WFContentItemFilter": filter])])
        XCTAssertTrue(unsafe.findsByFilter)
        XCTAssertTrue(HelperCatalogueCheck.problems(HelperCatalogue(helpers: [unsafe])).contains { $0.contains("\"check\" mode") })
        let agenda = try XCTUnwrap(HelperCatalogue.builtIn().helper("agenda.set-tags"))
        XCTAssertTrue(agenda.findsByFilter)
        let host = FakeHost([InstalledShortcut(id: "A", name: agenda.name, marker: agenda.marker, noInputBehavior: HelperLint.stopsOnNoInput)])
        host.output = Data("Buy milk\n\n".utf8)
        XCTAssertEqual(try agenda.check(["title": .string("Buy milk"), "tags": .array([])], host: host), ["Buy milk"])
        XCTAssertEqual(host.runs.first?.input.flatMap { String(data: $0, encoding: .utf8) }, #"{"check":true,"tags":[],"title":"Buy milk"}"#)
    }

    func testTheLibraryScanLintsOnlyHelpers() throws {
        // A non-helper with the same broken If is someone's own shortcut: not linted.
        let steps = [set("v"), ifStep(4, on: "v", text: "x")]
        XCTAssertFalse(HelperLint.problems(steps).isEmpty)
    }
}
