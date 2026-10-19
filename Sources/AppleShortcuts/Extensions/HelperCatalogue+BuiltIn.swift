//
//  HelperCatalogue+BuiltIn.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

public extension HelperCatalogue {

    /// The fleet's helpers, compiled in from `Helpers/*.json`, read strictly
    /// and checked.
    static func builtIn() throws -> HelperCatalogue {
        try decode(HelperCatalogueData.files)
    }

    /// Helper files by file name — `settings.focus.json` — each read strictly;
    /// a file must be named after its id.
    static func decode(_ files: [String: String]) throws -> HelperCatalogue {
        var helpers: [Helper] = []
        for (file, json) in files.sorted(by: { $0.key < $1.key }) {
            let helper: Helper
            do {
                helper = try JSONDecoder().decode(Helper.self, from: Data(json.utf8))
            } catch {
                throw HelperError.invalidCatalogue("\(file): \(error)")
            }
            guard file == "\(helper.id).json" else {
                throw HelperError.invalidCatalogue("\(file) holds \(helper.id); name it \(helper.id).json")
            }
            helpers.append(helper)
        }
        let catalogue = HelperCatalogue(helpers: helpers)
        let problems = catalogue.problems
        guard problems.isEmpty else { throw HelperError.invalidCatalogue(problems.joined(separator: "; ")) }
        return catalogue
    }
}
