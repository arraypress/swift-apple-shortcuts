//
//  RecipeStep+Codable.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension RecipeStep {

    /// The JSON keys.
    enum CodingKeys: String, CodingKey {
        case action
        case parameters
    }

    /// Reads a step; `parameters` may be left out.
    ///
    /// Plenty of actions take nothing — Get Current Focus, Get Clipboard —
    /// and a recipe that had to write `"parameters": {}` for each of them was
    /// refused for leaving it off, which is the wrong thing to refuse.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            action: try container.decode(String.self, forKey: .action),
            parameters: try container.decodeIfPresent([String: PlistValue].self, forKey: .parameters) ?? [:]
        )
    }
}
