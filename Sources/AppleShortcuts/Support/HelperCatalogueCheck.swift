//
//  HelperCatalogueCheck.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  Every rule a helper file must keep, checked on every load. A helper that
//  breaks one is not offered to anybody.
//

import Foundation

enum HelperCatalogueCheck {

    /// The separator between tool and title in a helper's name.
    static let separator = " · "

    /// Every problem, one sentence each; empty when the catalogue is sound.
    static func problems(_ catalogue: HelperCatalogue) -> [String] {
        var problems: [String] = []
        var ids = Set<String>()
        var names = Set<String>()
        let allNames = Set(catalogue.helpers.map { $0.name.lowercased() })

        for helper in catalogue.helpers {
            let at = helper.id
            if !ids.insert(helper.id).inserted { problems.append("\(at): the id is used twice") }
            if !names.insert(helper.name.lowercased()).inserted { problems.append("\(at): the name \"\(helper.name)\" is used twice") }
            if helper.id.range(of: #"^[a-z]+\.[a-z0-9-]+$"#, options: .regularExpression) == nil {
                problems.append("\(at): an id is <tool>.<what>, lower case")
            } else if !helper.id.hasPrefix(helper.tool + ".") {
                problems.append("\(at): the id must start with its tool, \(helper.tool).")
            }
            if helper.title.trimmingCharacters(in: .whitespaces).isEmpty
                || helper.title.contains(where: { "\"/:·\n".contains($0) }) {
                problems.append("\(at): a title is a few words with no quotes, slashes, colons or dots")
            }
            let description = helper.description.trimmingCharacters(in: .whitespaces)
            if description.isEmpty || description.contains("\n") || description.count > 140 {
                problems.append("\(at): a description is one line of plain English, at most 140 characters")
            }
            if helper.version < 0 || (helper.version == 0) != (helper.legacyName != nil) {
                problems.append("\(at): version is 1 or more; 0, with \"name\", only for a helper from before markers")
            }
            if let color = HelperPalette.toolColors[helper.tool] {
                if helper.icon.color != color { problems.append("\(at): \(helper.tool)'s helpers are \(color), not \(helper.icon.color)") }
            } else {
                problems.append("\(at): \(helper.tool) has no colour in HelperPalette.toolColors")
            }
            if HelperPalette.colors[helper.icon.color] == nil {
                problems.append("\(at): \(helper.icon.color) is not a Shortcuts colour")
            }
            if !HelperPalette.glyphs.contains(helper.icon.glyph) {
                problems.append("\(at): glyph \(helper.icon.glyph) is not one Shortcuts can draw")
            }
            if helper.steps.isEmpty { problems.append("\(at): a helper needs steps") }
            var fields = Set<String>()
            for field in helper.input {
                if field.name.isEmpty || !fields.insert(field.name).inserted {
                    problems.append("\(at): input field \"\(field.name)\" is blank or repeated")
                }
                if !field.choices.isEmpty, field.type != .string {
                    problems.append("\(at): only a string field takes choices (\(field.name))")
                }
            }
            if !helper.install.hasPrefix(helper.tool + " ") {
                problems.append("\(at): the install command must be \(helper.tool)'s")
            }
            for old in helper.replaces where allNames.contains(old.lowercased()) {
                problems.append("\(at): it replaces \"\(old)\", which is a current helper's name")
            }
            if !helper.experimental { problems += HelperLint.problems(of: helper).map { "\(at): \($0)" } }
            if helper.output.type != .none, helper.steps.last?.action != "is.workflow.actions.output" {
                problems.append("\(at): a helper that answers ends with Stop and Output (\"Do Nothing\"), so nothing is shown")
            }
            if !(helper.patience > 0 && helper.timeout > 0 && helper.patience <= helper.timeout) {
                problems.append("\(at): patience and timeout are seconds, patience no longer than timeout")
            }
        }
        return problems
    }

    /// Problems Shortcuts' own catalogue finds in each helper's steps: an
    /// action this Mac does not have, a parameter it does not take.
    ///
    /// Passing is not importability — the catalogue lists App Intents the
    /// Mac editor refuses — so every helper still needs one real import.
    static func actionProblems(_ catalogue: HelperCatalogue, builder: ShortcutBuilder) -> [String] {
        catalogue.helpers.flatMap { helper -> [String] in
            do {
                _ = try builder.build(helper.recipe)
            } catch {
                return ["\(helper.id): \(error.localizedDescription)"]
            }
            return Set(helper.steps.map(\.action)).sorted().compactMap { id in
                switch (try? builder.catalog.action(id: id))?.mac {
                case .refusedAtImport?: return "\(helper.id): \(id) is refused at import on the Mac"
                case .notOnMac?: return "\(helper.id): \(id) does not run on a Mac"
                default: return nil
                }
            }
        }
    }
}
