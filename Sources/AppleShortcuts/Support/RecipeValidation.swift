//
//  RecipeValidation.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  Refusing a recipe before it becomes a shortcut that quietly does nothing.
//

import Foundation

/// Checking a ``Recipe`` against the action catalogue.
///
/// The reason this exists: a shortcut file is a property list, and nothing
/// between the recipe and the person clicking Add checks it. A misspelt key —
/// `WFVolumme` — is a parameter no action reads, and an unknown identifier is
/// an action this Mac does not have. Both are cheaper to refuse here, against
/// the same catalogue Shortcuts' editor is built from, than to find on a run.
enum RecipeValidation {

    /// Throws for the first problem found.
    ///
    /// - Parameters:
    ///   - lookup: The catalogue entry for an identifier, if there is one.
    ///   - allIdentifiers: Every identifier, for suggestions.
    ///   - strict: Refuse parameter keys the catalogue does not list. The
    ///     catalogue describes what Shortcuts' editor offers, and a few
    ///     actions accept keys it leaves out; `strict: false` lets those
    ///     through while still checking the actions themselves.
    static func validate(
        _ recipe: Recipe,
        lookup: (String) -> CatalogAction?,
        allIdentifiers: [String],
        strict: Bool = true
    ) throws {
        guard !recipe.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ShortcutsError.invalidRecipe("a shortcut needs a name")
        }
        guard !recipe.actions.isEmpty else {
            throw ShortcutsError.invalidRecipe("a shortcut needs at least one action")
        }

        for (index, step) in recipe.actions.enumerated() {
            guard let action = lookup(step.action) else {
                throw ShortcutsError.unknownAction(step.action, suggestions: suggestions(for: step.action, in: allIdentifiers))
            }
            if strict {
                let valid = action.parameters.map(\.key)
                for key in step.parameters.keys.sorted() where !valid.contains(key) {
                    throw ShortcutsError.unknownParameter(action: step.action, key: key, valid: valid)
                }
            }
            if index == 0, step.parameters.values.contains(where: usesPrevious) {
                throw ShortcutsError.invalidRecipe("$previous in the first step — there is no step before it")
            }
        }
    }

    /// Whether a value uses `$previous` anywhere.
    static func usesPrevious(_ value: PlistValue) -> Bool {
        switch value {
        case .string(let string): return Tokens.segments(string).contains(.previous)
        case .array(let array): return array.contains(where: usesPrevious)
        case .dictionary(let dictionary): return dictionary.values.contains(where: usesPrevious)
        default: return false
        }
    }

    /// Up to three identifiers a misspelt one probably meant.
    ///
    /// By the last dotted component — the part a person actually wrote —
    /// so `setvolum` and `actions.volume` both find
    /// `is.workflow.actions.setvolume`.
    static func suggestions(for wanted: String, in identifiers: [String], limit: Int = 3) -> [String] {
        let tail = (wanted.split(separator: ".").last.map(String.init) ?? wanted).lowercased()
        guard tail.count >= 3 else { return [] }
        let stem = String(tail.prefix(max(3, tail.count - 2)))
        return identifiers
            .filter { ($0.split(separator: ".").last.map { $0.lowercased() } ?? "").contains(stem) }
            .sorted { $0.count < $1.count }
            .prefix(limit)
            .map { $0 }
    }
}
