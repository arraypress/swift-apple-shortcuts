//
//  RecipeStep.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One step of a ``Recipe``.
public struct RecipeStep: Sendable, Equatable, Codable {

    /// The action identifier, from ``ActionCatalog``.
    public let action: String

    /// Parameters by key. Strings may carry `$input` and `$previous`.
    public let parameters: [String: PlistValue]

    /// A step from its parts.
    public init(action: String, parameters: [String: PlistValue] = [:]) {
        self.action = action
        self.parameters = parameters
    }
}
