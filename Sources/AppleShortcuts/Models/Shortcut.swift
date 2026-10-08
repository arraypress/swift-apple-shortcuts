//
//  Shortcut.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A shortcut in the library.
public struct Shortcut: Sendable, Equatable, Codable, Identifiable {

    /// The identifier — a UUID that survives a rename, unlike the name.
    public let id: String

    /// The name it runs by.
    public let name: String

    /// The folder it lives in, when it lives in one.
    public let folder: String?

    /// A shortcut from its parts. ``ShortcutLibrary`` lists real ones.
    public init(id: String, name: String, folder: String? = nil) {
        self.id = id
        self.name = name
        self.folder = folder
    }
}
