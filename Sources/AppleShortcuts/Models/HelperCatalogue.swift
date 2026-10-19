//
//  HelperCatalogue.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Every fleet helper, one per JSON file in `Helpers/`.
public struct HelperCatalogue: Sendable, Equatable {

    /// The helpers, ordered by id.
    public let helpers: [Helper]

    /// A catalogue from its parts. ``builtIn()`` reads the compiled-in one.
    public init(helpers: [Helper]) {
        self.helpers = helpers.sorted { $0.id < $1.id }
    }
}
