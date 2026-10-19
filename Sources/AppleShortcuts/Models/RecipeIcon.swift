//
//  RecipeIcon.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A shortcut's tile: a colour and a glyph, as a shortcut file stores them.
///
/// Measured: the colour Shortcuts stores is the file's number, unchanged
/// (`4282601983` went in, `4282601983` was in the library), though the
/// editor's own shortcuts store the same colour as a signed 32-bit number
/// (`-23508481` is orange, `4271458815`).
public struct RecipeIcon: Sendable, Equatable, Hashable, Codable {

    /// The colour, as `WFWorkflowIconStartColor` — RGBA packed in 32 bits.
    public let color: Int

    /// The glyph, as `WFWorkflowIconGlyphNumber` — a private-use code point.
    public let glyph: Int

    /// An icon from its parts.
    public init(color: Int, glyph: Int) {
        self.color = color
        self.glyph = glyph
    }

    /// What Shortcuts gives a new shortcut: red, with its default glyph.
    public static let `default` = RecipeIcon(color: 4_282_601_983, glyph: 59511)
}
