//
//  ShortcutFolder.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A folder in the Shortcuts library.
public struct ShortcutFolder: Sendable, Equatable, Codable, Identifiable {

    /// The identifier.
    public let id: String

    /// The folder's name.
    public let name: String

    /// A folder from its parts.
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
