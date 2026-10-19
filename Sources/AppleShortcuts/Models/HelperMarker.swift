//
//  HelperMarker.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What an installed helper says about itself, read from its first step.
public struct HelperMarker: Sendable, Equatable, Codable {

    /// The helper's id — `settings.focus`.
    public let id: String

    /// The version it was built as.
    public let version: Int

    /// A fingerprint of the steps it was built from.
    public let recipe: String

    /// A marker from its parts.
    public init(id: String, version: Int, recipe: String) {
        self.id = id
        self.version = version
        self.recipe = recipe
    }
}
