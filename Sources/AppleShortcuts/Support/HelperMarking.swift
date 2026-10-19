//
//  HelperMarking.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  The comment a helper carries as its first step: what it does and who put
//  it there, for the person who opens it in Shortcuts, and one bracketed line
//  for the tool.
//

import CryptoKit
import Foundation

/// Writing and reading helper markers. Pure.
enum HelperMarking {

    /// The comment action — in the catalogue on every Mac, shown in the editor.
    static let commentAction = "is.workflow.actions.comment"

    /// Its text parameter.
    static let commentKey = "WFCommentActionText"

    /// The shortcut as built: the marker comment, then the helper's steps, on
    /// the fleet's tile.
    static func recipe(for helper: Helper) -> Recipe {
        Recipe(name: helper.name,
               actions: [RecipeStep(action: commentAction, parameters: [commentKey: .string(comment(for: helper))])]
                   + helper.steps,
               icon: HelperPalette.recipeIcon(helper.icon),
               noInputError: noInputMessage(for: helper))
    }

    /// What the marker step says.
    static func comment(for helper: Helper) -> String {
        """
        \(helper.description)

        Installed by \(helper.tool) — don't edit; reinstall with `\(helper.install)`.

        \(line(for: marker(for: helper)))
        """
    }

    /// What a helper says when run by hand with no input.
    static func noInputMessage(for helper: Helper) -> String? {
        guard !helper.input.isEmpty else { return nil }
        return "This is a helper for the \(helper.tool) command-line tool, which runs it with its input. Don't run it by hand."
    }

    /// The marker a helper's build carries.
    static func marker(for helper: Helper) -> HelperMarker {
        HelperMarker(id: helper.id, version: helper.version, recipe: fingerprint(helper))
    }

    /// The machine line: `[helper id=settings.focus version=1 recipe=3f9a1c2e]`.
    static func line(for marker: HelperMarker) -> String {
        "[helper id=\(marker.id) version=\(marker.version) recipe=\(marker.recipe)]"
    }

    /// The marker in a comment's text, wherever the line sits in it.
    static func parse(_ text: String) -> HelperMarker? {
        let pattern = #"\[helper id=([a-z]+\.[a-z0-9-]+) version=(\d+) recipe=([0-9a-f]{8})\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        func group(_ index: Int) -> String? {
            Range(match.range(at: index), in: text).map { String(text[$0]) }
        }
        guard let id = group(1), let version = group(2).flatMap(Int.init), let recipe = group(3) else { return nil }
        return HelperMarker(id: id, version: version, recipe: recipe)
    }

    /// The marker of a stored shortcut: the first comment step's, if it has one.
    ///
    /// Only the FIRST comment is read — a helper puts its marker there, and a
    /// later comment quoting a marker is not a claim to be one.
    static func marker(in steps: [ShortcutStep]) -> HelperMarker? {
        guard let comment = steps.first(where: { $0.action == commentAction }),
              case .string(let text)? = comment.parameters[commentKey] else { return nil }
        return parse(text)
    }

    /// The first 8 hex digits of the SHA-256 of the name and steps, as
    /// sorted-key JSON.
    ///
    /// The wording, version and icon are not in it: a helper whose steps did
    /// not change does not need adding again because its description did.
    static func fingerprint(_ helper: Helper) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = (try? encoder.encode(Recipe(name: helper.name, actions: helper.steps))) ?? Data()
        return SHA256.hash(data: data).prefix(4).map { String(format: "%02x", $0) }.joined()
    }
}

public extension Helper {

    /// What it is added and run under: `settings · Set Focus`.
    var name: String { legacyName ?? "\(tool)\(HelperCatalogueCheck.separator)\(title)" }
}
