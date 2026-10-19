//
//  HelperCatalogueTests.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  The helper files: every one loads, keeps the rules, and is what the
//  compiled-in copy says.
//

import XCTest
@testable import AppleShortcuts

final class HelperCatalogueTests: XCTestCase {

    /// The repo's Helpers/ folder.
    static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Helpers")

    func testTheBuiltInCatalogueLoadsAndKeepsEveryRule() throws {
        let catalogue = try HelperCatalogue.builtIn()
        XCTAssertFalse(catalogue.helpers.isEmpty)
        XCTAssertEqual(catalogue.problems, [])
        for helper in catalogue.helpers { XCTAssertEqual(helper.icon.color, HelperPalette.toolColors[helper.tool], helper.id) }
        for helper in catalogue.helpers {
            XCTAssertTrue(HelperPalette.glyphs.contains(helper.icon.glyph), helper.id)
            XCTAssertNotNil(HelperPalette.symbol(helper.icon.glyph), helper.id)
            XCTAssertNotEqual(helper.icon.glyph, HelperPalette.defaultGlyph, "\(helper.id) needs a glyph of its own")
            XCTAssertFalse(helper.description.lowercased().contains("arraypress"), helper.id)
        }
    }

    func testTheCompiledInCopyIsTheFolder() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: Self.folder.path).filter { $0.hasSuffix(".json") }
        XCTAssertEqual(Set(names), Set(HelperCatalogueData.files.keys), "run python3 Scripts/gen-helpers.py")
        for name in names {
            let disk = try String(contentsOf: Self.folder.appendingPathComponent(name), encoding: .utf8)
            XCTAssertEqual(disk.trimmingCharacters(in: .whitespacesAndNewlines),
                           HelperCatalogueData.files[name]?.trimmingCharacters(in: .whitespacesAndNewlines),
                           "\(name) differs from the compiled-in copy — run python3 Scripts/gen-helpers.py")
        }
    }

    func testEveryHelpersStepsAreKnownToThisMac() throws {
        let catalog: ActionCatalog
        do { catalog = try ActionCatalog() } catch { throw XCTSkip("no action catalogue on this Mac") }
        XCTAssertEqual(try HelperCatalogue.builtIn().actionProblems(builder: ShortcutBuilder(catalog: catalog)), [])
    }

    // MARK: - Rules

    func good(_ id: String = "settings.focus", tool: String = "settings", title: String = "Set Focus",
              description: String = "Turns a Focus on or off.", version: Int = 1, glyph: Int = 61440,
              color: String = "blue", input: [HelperField] = [], steps: [RecipeStep]? = nil,
              replaces: [String] = [], install: String? = nil, legacyName: String? = nil,
              patience: Double = 5, timeout: Double = 30) -> Helper {
        Helper(id: id, tool: tool, title: title, description: description, version: version,
               icon: HelperIcon(glyph: glyph, color: color), input: input,
               steps: steps ?? [RecipeStep(action: "is.workflow.actions.dnd.getfocus")], replaces: replaces,
               install: install, legacyName: legacyName, patience: patience, timeout: timeout)
    }

    func problems(_ helpers: Helper...) -> String {
        HelperCatalogueCheck.problems(HelperCatalogue(helpers: helpers)).joined(separator: "; ")
    }

    func testASoundHelperHasNoProblems() {
        XCTAssertEqual(problems(good()), "")
        XCTAssertEqual(problems(good(version: 0, legacyName: "settings focus")), "")
    }

    func testEachRule() {
        let cases: [(Helper, String)] = [
            (good("Settings.focus"), "lower case"),
            (good("notes.focus"), "must start with its tool"),
            (good(title: "Set: Focus"), "a title is a few words"),
            (good(title: "Set · Focus"), "a title is a few words"),
            (good(title: " "), "a title is a few words"),
            (good(description: ""), "one line of plain English"),
            (good(description: "two\nlines"), "one line of plain English"),
            (good(description: String(repeating: "a", count: 141)), "one line of plain English"),
            (good(version: 0), "version is 1 or more"),
            (good(version: 1, legacyName: "x"), "version is 1 or more"),
            (good(version: -1, legacyName: "x"), "version is 1 or more"),
            (good(color: "red"), "settings's helpers are blue, not red"),
            (good("zzz.focus", tool: "zzz", install: "zzz doctor --install"), "zzz has no colour"),
            (good(color: "mauve"), "mauve is not a Shortcuts colour"),
            (good(glyph: 12345), "glyph 12345 is not one Shortcuts can draw"),
            (good(steps: []), "a helper needs steps"),
            (good(input: [HelperField(name: "a", type: .bool, description: ""), HelperField(name: "a", type: .bool, description: "")]),
             "is blank or repeated"),
            (good(input: [HelperField(name: "", type: .bool, description: "")]), "is blank or repeated"),
            (good(input: [HelperField(name: "a", type: .bool, description: "", choices: ["x"])]), "only a string field takes choices"),
            (good(install: "agenda doctor --install"), "the install command must be settings's"),
            (good(replaces: ["settings · Set Focus"]), "which is a current helper's name"),
            (good(patience: 40, timeout: 30), "patience and timeout"),
            (good(patience: 0), "patience and timeout"),
        ]
        for (helper, expected) in cases {
            XCTAssertTrue(problems(helper).contains(expected), "\(expected) — got: \(problems(helper))")
        }
        XCTAssertTrue(problems(good(), good(title: "Other")).contains("the id is used twice"))
        XCTAssertTrue(problems(good(), good("settings.other")).contains("is used twice"))
    }

    // MARK: - Reading files

    let file = #"""
    {"id": "settings.focus", "tool": "settings", "title": "Set Focus", "description": "Turns a Focus on or off.",
     "version": 1, "icon": {"glyph": 61440, "color": "blue"},
     "input": [{"name": "on", "type": "bool", "description": "on or off"}],
     "output": {"type": "text", "description": "the Focus now"},
     "steps": [{"action": "is.workflow.actions.dnd.getfocus"},
               {"action": "is.workflow.actions.output", "parameters": {"WFOutput": "$previous", "WFNoOutputSurfaceBehavior": "Do Nothing"}}],
     "install": "settings doctor --install", "timeout": 12}
    """#

    func testAFileReadsWithItsDefaults() throws {
        let helper = try XCTUnwrap(HelperCatalogue.decode(["settings.focus.json": file]).helper("settings.focus"))
        XCTAssertEqual(helper.timeout, 12)
        XCTAssertEqual(helper.patience, 5)
        XCTAssertEqual(helper.input.first?.required, true)
        XCTAssertEqual(helper.output, HelperOutput(type: .text, description: "the Focus now"))
        XCTAssertEqual(helper.notes, [])
        XCTAssertNil(helper.legacyName)
        // And it writes back out as a file that reads the same.
        let again = try JSONDecoder().decode(Helper.self, from: JSONEncoder().encode(helper))
        XCTAssertEqual(again, helper)
    }

    func testUnknownKeysAnywhereRefuseTheFile() {
        let typos = [
            file.replacingOccurrences(of: "\"timeout\"", with: "\"timout\""),
            file.replacingOccurrences(of: "\"glyph\"", with: "\"glyf\""),
            file.replacingOccurrences(of: "\"color\": \"blue\"", with: "\"color\": \"blue\", \"colour\": \"blue\""),
            file.replacingOccurrences(of: "\"type\": \"bool\"", with: "\"type\": \"bool\", \"default\": true"),
            file.replacingOccurrences(of: "\"type\": \"text\"", with: "\"type\": \"text\", \"shape\": 1"),
            file.replacingOccurrences(of: "{\"action\": \"is.workflow.actions.dnd.getfocus\"}",
                                      with: "{\"action\": \"is.workflow.actions.dnd.getfocus\", \"parameter\": {}}"),
            file.replacingOccurrences(of: "\"type\": \"bool\"", with: "\"type\": \"boolean\""),
        ]
        for typo in typos {
            XCTAssertNotEqual(typo, file)
            XCTAssertThrowsError(try HelperCatalogue.decode(["settings.focus.json": typo]), typo)
        }
    }

    func testAFileIsNamedAfterItsIdAndMustKeepTheRules() {
        XCTAssertThrowsError(try HelperCatalogue.decode(["focus.json": file])) {
            XCTAssertTrue($0.localizedDescription.contains("name it settings.focus.json"))
        }
        let blue = file.replacingOccurrences(of: "\"color\": \"blue\"", with: "\"color\": \"red\"")
        XCTAssertThrowsError(try HelperCatalogue.decode(["settings.focus.json": blue])) {
            XCTAssertTrue($0.localizedDescription.contains("settings's helpers are blue, not red"))
        }
    }

    func testLookups() throws {
        let catalogue = try HelperCatalogue.decode(["settings.focus.json": file])
        XCTAssertEqual(catalogue["settings.focus"].title, "Set Focus")
        XCTAssertNil(catalogue.helper("settings.nope"))
        XCTAssertEqual(catalogue.helpers(for: "settings").map(\.id), ["settings.focus"])
        XCTAssertEqual(catalogue.helpers(for: "notes"), [])
    }
}
