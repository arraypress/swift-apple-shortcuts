//
//  HelperField.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One field of a helper's JSON input.
public struct HelperField: Sendable, Equatable, Codable {

    /// The JSON key.
    public let name: String

    /// What it holds.
    public let type: HelperFieldType

    /// Whether a run must give it.
    public let required: Bool

    /// What it means, in a few words.
    public let description: String

    /// The values it may take, when there is a fixed set.
    public let choices: [String]

    /// A field from its parts.
    public init(name: String, type: HelperFieldType, required: Bool = true, description: String,
                choices: [String] = []) {
        self.name = name
        self.type = type
        self.required = required
        self.description = description
        self.choices = choices
    }
}

/// The JSON types a helper field holds.
public enum HelperFieldType: String, Sendable, Equatable, Codable, CaseIterable {
    case string, bool, number, list
}

/// What a helper hands back.
public struct HelperOutput: Sendable, Equatable, Codable {

    /// Its shape.
    public let type: HelperOutputType

    /// What it is, in a few words.
    public let description: String?

    /// An output from its parts.
    public init(type: HelperOutputType, description: String? = nil) {
        self.type = type
        self.description = description
    }
}

/// The shapes a helper's output takes.
public enum HelperOutputType: String, Sendable, Equatable, Codable, CaseIterable {
    /// Nothing: the caller reads the state it changed.
    case none
    /// Text, as the last step produced it.
    case text
    /// A JSON document.
    case json
}

/// A helper's tile: a glyph, on the fleet's colour.
public struct HelperIcon: Sendable, Equatable, Codable {

    /// The glyph number.
    public let glyph: Int

    /// The colour's palette name: the owning tool's (``HelperPalette/toolColors``).
    public let color: String

    /// An icon from its parts.
    public init(glyph: Int, color: String = "sage") {
        self.glyph = glyph
        self.color = color
    }
}
