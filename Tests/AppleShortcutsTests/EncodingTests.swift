//
//  EncodingTests.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  Nothing here runs a shortcut or opens Shortcuts. These are the rules that
//  decide what a built file says, and the golden values were written by
//  Shortcuts itself, not by this library.
//

import XCTest
@testable import AppleShortcuts

final class TokenTests: XCTestCase {

    func testSegments() {
        XCTAssertEqual(Tokens.segments("You said: $input"), [.text("You said: "), .input])
        XCTAssertEqual(Tokens.segments("$previous and $input"), [.previous, .text(" and "), .input])
        XCTAssertEqual(Tokens.segments("plain"), [.text("plain")])
    }

    func testDollarsThatAreNotVariablesSurvive() {
        XCTAssertEqual(Tokens.segments("$5 off"), [.text("$5 off")])
        XCTAssertEqual(Tokens.segments("$$input"), [.text("$input")])
        XCTAssertFalse(Tokens.usesVariables("$$input costs $5"))
    }

    func testPreviousMatchesWhatShortcutsWroteItself() throws {
        // After its first command-line run, Shortcuts appended a Stop and
        // Output step to a shortcut this library built, referring to the Text
        // step before it. This is that parameter, copied from the library's
        // database. The encoder must produce exactly it.
        let written: [String: Any] = [
            "WFSerializationType": "WFTextTokenString",
            "Value": [
                "string": "\u{FFFC}",
                "attachmentsByRange": [
                    "{0, 1}": ["OutputName": "Text", "OutputUUID": "0E1F2A3B-0000-4000-8000-000000000001",
                               "Type": "ActionOutput"],
                ],
            ],
        ]
        let encoded = Tokens.encode("$previous", isTextParameter: true,
                                    previous: ("0E1F2A3B-0000-4000-8000-000000000001", "Text"))
        XCTAssertEqual(encoded as? NSDictionary, written as NSDictionary)
    }

    func testRangesCountUTF16() throws {
        // An emoji is two UTF-16 units; a range that counted Characters would
        // point one unit early and Shortcuts would attach to the wrong place.
        let encoded = try XCTUnwrap(Tokens.encode("😀 $input", isTextParameter: true, previous: nil) as? [String: Any])
        let value = try XCTUnwrap(encoded["Value"] as? [String: Any])
        let ranges = try XCTUnwrap(value["attachmentsByRange"] as? [String: Any])
        XCTAssertEqual(Array(ranges.keys), ["{3, 1}"])
    }

    func testAWholeVariableInAContentSlotIsAnAttachment() throws {
        let encoded = try XCTUnwrap(Tokens.encode("$input", isTextParameter: false, previous: nil) as? [String: Any])
        XCTAssertEqual(encoded["WFSerializationType"] as? String, "WFTextTokenAttachment")
    }

    func testStringsWithoutVariablesAreLeftAlone() {
        XCTAssertEqual(Tokens.encode("hello", isTextParameter: true, previous: nil) as? String, "hello")
        XCTAssertEqual(Tokens.encode("cost $$5", isTextParameter: true, previous: nil) as? String, "cost $5")
    }
}

final class RecipeEncodingTests: XCTestCase {

    let context = RecipeEncoding.Context(outputName: { _ in "Text" }, isTextParameter: { _, _ in true })

    func testTheShapeShortcutsAccepted() throws {
        // The probe file Shortcuts added and ran: one Text step.
        var ids = ["0E1F2A3B-0000-4000-8000-000000000001"].makeIterator()
        let recipe = Recipe(name: "Shortcut Probe", actions: [
            RecipeStep(action: "is.workflow.actions.gettext", parameters: ["WFTextActionText": .string("hello from shortcut")]),
        ])
        let workflow = RecipeEncoding.workflow(recipe, context: context, uuid: { ids.next()! })
        let actions = try XCTUnwrap(workflow["WFWorkflowActions"] as? [[String: Any]])
        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions[0]["WFWorkflowActionIdentifier"] as? String, "is.workflow.actions.gettext")
        let parameters = try XCTUnwrap(actions[0]["WFWorkflowActionParameters"] as? [String: Any])
        XCTAssertEqual(parameters["WFTextActionText"] as? String, "hello from shortcut")
        XCTAssertEqual(parameters["UUID"] as? String, "0E1F2A3B-0000-4000-8000-000000000001")
        XCTAssertEqual(workflow["WFWorkflowHasShortcutInputVariables"] as? Bool, false)
    }

    func testPreviousPointsAtTheStepBefore() throws {
        var counter = 0
        let recipe = Recipe(name: "Chain", actions: [
            RecipeStep(action: "is.workflow.actions.gettext", parameters: ["WFTextActionText": .string("hi")]),
            RecipeStep(action: "is.workflow.actions.gettext", parameters: ["WFTextActionText": .string("$previous!")]),
        ])
        let workflow = RecipeEncoding.workflow(recipe, context: context, uuid: { counter += 1; return "U\(counter)" })
        let second = try XCTUnwrap((workflow["WFWorkflowActions"] as? [[String: Any]])?[1]["WFWorkflowActionParameters"] as? [String: Any])
        let value = try XCTUnwrap((second["WFTextActionText"] as? [String: Any])?["Value"] as? [String: Any])
        let attachment = try XCTUnwrap((value["attachmentsByRange"] as? [String: Any])?["{0, 1}"] as? [String: Any])
        XCTAssertEqual(attachment["OutputUUID"] as? String, "U1")
        XCTAssertEqual(attachment["OutputName"] as? String, "Text")
    }

    func testUsingInputMakesTheShortcutTakeInput() {
        let recipe = Recipe(name: "Echo", actions: [
            RecipeStep(action: "is.workflow.actions.gettext", parameters: ["WFTextActionText": .string("$input")]),
        ])
        let workflow = RecipeEncoding.workflow(recipe, context: context)
        XCTAssertEqual(workflow["WFWorkflowHasShortcutInputVariables"] as? Bool, true)
        XCTAssertEqual((workflow["WFWorkflowInputContentItemClasses"] as? [String])?.count, RecipeEncoding.inputClasses.count)
    }

    func testItIsAPropertyList() throws {
        let recipe = Recipe(name: "x", actions: [RecipeStep(action: "a", parameters: ["n": .integer(3), "b": .bool(true)])])
        let data = try RecipeEncoding.data(RecipeEncoding.workflow(recipe, context: context))
        XCTAssertEqual(data.prefix(6), Data("bplist".utf8))
    }
}

final class ValidationTests: XCTestCase {

    let volume = CatalogAction(id: "is.workflow.actions.setvolume", name: "Set Volume", app: "com.apple.shortcuts",
                               kind: "action", parameters: [CatalogParameter(key: "WFVolume"), CatalogParameter(key: "WFVolumeSetting")])
    let ids = ["is.workflow.actions.setvolume", "is.workflow.actions.gettext", "is.workflow.actions.dnd.set"]

    func validate(_ recipe: Recipe, strict: Bool = true) throws {
        try RecipeValidation.validate(recipe, lookup: { $0 == self.volume.id ? self.volume : nil }, allIdentifiers: ids, strict: strict)
    }

    func testAMisspeltActionSuggestsTheRealOne() {
        XCTAssertThrowsError(try validate(Recipe(name: "x", actions: [RecipeStep(action: "is.workflow.actions.setvolum")]))) {
            XCTAssertEqual($0 as? ShortcutsError, .unknownAction("is.workflow.actions.setvolum", suggestions: ["is.workflow.actions.setvolume"]))
        }
    }

    func testAMisspeltKeyIsRefusedWithTheRealOnes() {
        let recipe = Recipe(name: "x", actions: [RecipeStep(action: volume.id, parameters: ["WFVolumme": .double(0.2)])])
        XCTAssertThrowsError(try validate(recipe)) {
            XCTAssertEqual($0 as? ShortcutsError, .unknownParameter(action: self.volume.id, key: "WFVolumme", valid: ["WFVolume", "WFVolumeSetting"]))
        }
        XCTAssertNoThrow(try validate(recipe, strict: false))
    }

    func testPreviousNeedsAStepBefore() {
        let recipe = Recipe(name: "x", actions: [RecipeStep(action: volume.id, parameters: ["WFVolume": .string("$previous")])])
        XCTAssertThrowsError(try validate(recipe, strict: false))
    }

    func testEmptyRecipesAreRefused() {
        XCTAssertThrowsError(try validate(Recipe(name: " ", actions: [RecipeStep(action: volume.id)])))
        XCTAssertThrowsError(try validate(Recipe(name: "x", actions: [])))
    }
}

final class CommandTests: XCTestCase {

    func testListLines() {
        XCTAssertEqual(ShortcutsCommand.parseListLine("Shortcut Probe (B360396D-130E-4622-8AC2-FCB360ABDB25)")?.name, "Shortcut Probe")
        // A name with its own parentheses keeps them.
        let parens = ShortcutsCommand.parseListLine("Resize (fast) (B360396D-130E-4622-8AC2-FCB360ABDB25)")
        XCTAssertEqual(parens?.name, "Resize (fast)")
        XCTAssertNil(ShortcutsCommand.parseListLine("Resize (fast)"))
    }

    func testCRLFListings() {
        let data = Data("A (B360396D-130E-4622-8AC2-FCB360ABDB25)\r\nB (0C65F42A-2AFA-42A9-910F-38D952CFCC28)\r\n".utf8)
        XCTAssertEqual(ShortcutsCommand.parseList(data).map(\.name), ["A", "B"])
    }

    func testTheMissingShortcutMessage() {
        // Recorded from `shortcuts run "No Such Shortcut 7f3c"`, exit 1.
        let stderr = "Error: The operation couldn’t be completed. Couldn’t find shortcut\n"
        XCTAssertEqual(ShortcutsCommand.failure(status: 1, stderr: stderr, shortcut: "x"), .noSuchShortcut("x"))
        XCTAssertEqual(ShortcutsCommand.failure(status: 1, stderr: "Error: Something else broke", shortcut: "x"),
                       .runFailed("Something else broke"))
    }

    func testFolderLookup() {
        let folders = [ShortcutFolder(id: "D78C4B81-AB7E-422E-9A19-30ED332BBFAD", name: "Testing")]
        XCTAssertEqual(ShortcutLibrary.folder("testing", in: folders)?.name, "Testing")
        XCTAssertEqual(ShortcutLibrary.folder("d78c4b81-ab7e-422e-9a19-30ed332bbfad", in: folders)?.name, "Testing")
        XCTAssertNil(ShortcutLibrary.folder("Work", in: folders))
    }
}

final class ValueTests: XCTestCase {

    func testJSONReadsAsWritten() throws {
        let decoded = try JSONDecoder().decode([String: PlistValue].self, from: Data(#"{"v":0.5,"n":3,"b":true,"s":"x","a":[1]}"#.utf8))
        XCTAssertEqual(decoded["v"], .double(0.5))
        XCTAssertEqual(decoded["n"], .integer(3))
        XCTAssertEqual(decoded["b"], .bool(true))
        XCTAssertEqual(decoded["a"], .array([.integer(1)]))
        let encoded = String(decoding: try JSONEncoder().encode(PlistValue.dictionary(["v": .double(0.5)])), as: UTF8.self)
        XCTAssertEqual(encoded, #"{"v":0.5}"#)
    }

    func testBooleansAreNotNumbers() {
        // NSNumber carries both; a true read as 1 would be written back as a
        // number, which Shortcuts reads as a different value.
        XCTAssertEqual(PlistValueCoding.value(true as NSNumber), .bool(true))
        XCTAssertEqual(PlistValueCoding.value(1 as NSNumber), .integer(1))
        XCTAssertEqual(PlistValueCoding.value(0.5 as NSNumber), .double(0.5))
    }

    func testStoredStepsDropTheirUUID() throws {
        let stored: [[String: Any]] = [["WFWorkflowActionIdentifier": "is.workflow.actions.gettext",
                                        "WFWorkflowActionParameters": ["WFTextActionText": "hi", "UUID": "X"]]]
        let data = try PropertyListSerialization.data(fromPropertyList: stored, format: .binary, options: 0)
        XCTAssertEqual(try StepDecoding.steps(from: data),
                       [ShortcutStep(action: "is.workflow.actions.gettext", parameters: ["WFTextActionText": .string("hi")])])
    }

    func testFileNamesKeepTheName() {
        // Shortcuts names an added shortcut after its file.
        XCTAssertEqual(FileNaming.fileName(for: "Quiet Hours"), "Quiet Hours.shortcut")
        XCTAssertEqual(FileNaming.fileName(for: "a/b: c"), "a-b- c.shortcut")
        XCTAssertEqual(FileNaming.fileName(for: ".hidden"), "hidden.shortcut")
    }
}
