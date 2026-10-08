//
//  RecipeEncoding.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  A recipe as the property list a .shortcut file holds.
//

import Foundation

/// Turning a ``Recipe`` into a shortcut file's contents.
///
/// The shape was checked against Shortcuts itself, not a write-up of it: a
/// file built this way, signed and opened, was added to a real library and
/// stored with its action exactly as written — identifier, parameters and
/// step UUID — and running it printed what the recipe said. A second, using
/// `$input` and `$previous`, was added and run the same way:
/// `shortcut run "Echo Probe" "hi there"` printed `You said: hi there
/// (twice)` — text input reached `$input`, and the second step read the
/// first's output.
enum RecipeEncoding {

    /// What encoding needs to know about each action, from the catalogue.
    struct Context {

        /// What an action's output is called — the name `$previous` refers
        /// to it by. Falls back to "Result".
        var outputName: (String) -> String?

        /// Whether a parameter holds text, by action and key.
        var isTextParameter: (String, String) -> Bool
    }

    /// The content types a shortcut that takes input accepts.
    ///
    /// Every type, because a recipe that uses `$input` cannot know what it
    /// will be run with, and a type left out is an input Shortcuts refuses.
    static let inputClasses = [
        "WFAppContentItem", "WFArticleContentItem", "WFContactContentItem", "WFDateContentItem",
        "WFEmailAddressContentItem", "WFFolderContentItem", "WFGenericFileContentItem",
        "WFImageContentItem", "WFLocationContentItem", "WFDCMapsLinkContentItem",
        "WFAVAssetContentItem", "WFPDFContentItem", "WFPhoneNumberContentItem",
        "WFRichTextContentItem", "WFSafariWebPageContentItem", "WFStringContentItem",
        "WFURLContentItem",
    ]

    /// The workflow dictionary.
    ///
    /// - Parameter uuid: Injected so a test gets the same file twice.
    static func workflow(
        _ recipe: Recipe,
        context: Context,
        uuid: () -> String = { UUID().uuidString }
    ) -> [String: Any] {
        var actions: [[String: Any]] = []
        var previous: (uuid: String, name: String)?
        var usesInput = false

        for step in recipe.actions {
            let id = uuid()
            var parameters: [String: Any] = ["UUID": id]
            for (key, value) in step.parameters {
                if case .string(let string) = value {
                    if Tokens.segments(string).contains(.input) { usesInput = true }
                    parameters[key] = Tokens.encode(
                        string,
                        isTextParameter: context.isTextParameter(step.action, key),
                        previous: previous
                    )
                } else {
                    parameters[key] = PlistValueCoding.object(value)
                }
            }
            actions.append([
                "WFWorkflowActionIdentifier": step.action,
                "WFWorkflowActionParameters": parameters,
            ])
            previous = (id, context.outputName(step.action) ?? "Result")
        }

        return [
            "WFWorkflowClientVersion": "2700.0.0",
            "WFWorkflowMinimumClientVersion": 900,
            "WFWorkflowMinimumClientVersionString": "900",
            "WFWorkflowIcon": [
                "WFWorkflowIconStartColor": 4_282_601_983,
                "WFWorkflowIconGlyphNumber": 59511,
            ],
            "WFWorkflowTypes": [String](),
            "WFWorkflowImportQuestions": [Any](),
            "WFWorkflowHasShortcutInputVariables": usesInput,
            "WFWorkflowInputContentItemClasses": usesInput ? inputClasses : ["WFStringContentItem"],
            "WFWorkflowActions": actions,
        ]
    }

    /// The workflow as a binary property list, unsigned.
    static func data(_ workflow: [String: Any]) throws -> Data {
        do {
            return try PropertyListSerialization.data(fromPropertyList: workflow, format: .binary, options: 0)
        } catch {
            throw ShortcutsError.invalidRecipe("could not be written as a property list: \(error.localizedDescription)")
        }
    }
}
