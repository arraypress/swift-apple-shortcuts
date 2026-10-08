//
//  ShortcutBuilder.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  A recipe, checked, written as a signed shortcut file — and offered to a
//  person, who decides whether it joins their library.
//
//  THERE IS NO WAY TO ADD A SHORTCUT WITHOUT A PERSON, and this does not look
//  for one. Shortcuts' scripting dictionary is read-only — no `make` — and
//  writing to the library's database behind a running, iCloud-synced app is
//  corruption waiting for the next sync. Opening a signed file shows Shortcuts'
//  own "Add Shortcut" sheet, and somebody clicks it. A shortcut can do almost
//  anything, so that click is the right place for the decision to be.
//

import AppKit
import Foundation

/// Builds shortcut files from recipes.
///
/// ```swift
/// let builder = try ShortcutBuilder()
/// let file = try builder.write(recipe, to: .downloadsDirectory)
/// try ShortcutBuilder.offer(file)    // Shortcuts asks a person to add it
/// ```
public struct ShortcutBuilder {

    /// The catalogue recipes are checked against.
    public let catalog: ActionCatalog

    /// A builder over the given catalogue, or this Mac's.
    public init(catalog: ActionCatalog? = nil) throws {
        self.catalog = try catalog ?? ActionCatalog()
    }

    /// The unsigned property list for a recipe, after checking it.
    ///
    /// - Parameter strict: Refuse parameter keys the catalogue does not list.
    public func build(_ recipe: Recipe, strict: Bool = true) throws -> Data {
        var known: [String: CatalogAction] = [:]
        for id in Set(recipe.actions.map(\.action)) {
            known[id] = try? catalog.action(id: id)
        }
        try RecipeValidation.validate(
            recipe,
            lookup: { known[$0] },
            allIdentifiers: (try? catalog.identifiers()) ?? [],
            strict: strict
        )

        let context = RecipeEncoding.Context(
            outputName: { known[$0]?.outputName },
            isTextParameter: { action, key in
                let type = known[action]?.parameters.first { $0.key == key }?.type
                return type.map { Tokens.textTypes.contains($0) } ?? true
            }
        )
        return try RecipeEncoding.data(RecipeEncoding.workflow(recipe, context: context))
    }

    /// Writes a recipe as a signed `.shortcut` file.
    ///
    /// The file is named after the recipe, because Shortcuts names an added
    /// shortcut after the FILE — measured: `Shortcut Probe.shortcut` became
    /// the shortcut "Shortcut Probe".
    ///
    /// - Returns: The signed file.
    public func write(
        _ recipe: Recipe,
        to directory: URL,
        mode: SigningMode = .peopleWhoKnowMe,
        strict: Bool = true
    ) throws -> URL {
        let unsigned = try build(recipe, strict: strict)
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("shortcut-unsigned-\(UUID().uuidString).shortcut")
        try unsigned.write(to: scratch)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let signed = directory.appendingPathComponent(FileNaming.fileName(for: recipe.name))
        try Self.sign(scratch, to: signed, mode: mode)
        return signed
    }

    /// Signs a shortcut file with `shortcuts sign`.
    ///
    /// Shortcuts opens only signed files. The output is an Apple Encrypted
    /// Archive (`AEA1`), not a property list, so a signed file cannot be read
    /// back with `plutil` — keep the recipe.
    public static func sign(_ file: URL, to output: URL, mode: SigningMode = .peopleWhoKnowMe) throws {
        guard let outcome = try ProcessRunner.run(
            ShortcutsCommand.path,
            ["sign", "--mode", mode.rawValue, "--input", file.path, "--output", output.path],
            timeout: 120
        ) else { throw ShortcutsError.signingFailed("timed out after 120 s") }

        // Exit status alone is not trusted: success means a non-empty file
        // where one was asked for.
        let size = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int) ?? 0
        guard outcome.status == 0, size > 0 else {
            let reason = outcome.error.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ShortcutsError.signingFailed(reason.isEmpty ? "no file was written" : reason)
        }
    }

    /// Opens a signed file in Shortcuts, which shows its "Add Shortcut" sheet.
    ///
    /// Nothing is added until a person clicks. Measured, the sheet that
    /// appeared listed **none** of the shortcut's actions — "Please review
    /// this shortcut before adding it" above an empty space — so whoever
    /// clicks is relying on what they were told about it, not on the sheet.
    public static func offer(_ file: URL) throws {
        guard NSWorkspace.shared.open(file) else {
            throw ShortcutsError.unavailable("Shortcuts would not open \(file.lastPathComponent)")
        }
    }
}
