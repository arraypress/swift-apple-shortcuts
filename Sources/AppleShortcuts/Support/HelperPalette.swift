//
//  HelperPalette.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  The colours and glyphs a helper's tile may use.
//
//  Colours: Shortcuts' fifteen tile colours, by the names the macOS 27 colour
//  picker shows, in its order. The numbers are what a shortcut file stores.
//  MEASURED: red (a built file's default), orange (an editor-made shortcut,
//  stored signed), yellow, green, blue, indigo and purple (Apple's Gallery
//  shortcuts in WorkflowKit), and sage (the first helpers, which the person
//  saw as sage). The rest are the long-standing values community tools write.
//
//  Each tool has ONE colour, so a person's library groups the fleet's helpers
//  by tool at a glance; the glyph says what each one does.
//
//  Glyphs: the 868 numbers Shortcuts maps to an SF Symbol (HelperGlyphs,
//  generated from WorkflowUICore's own table).
//

import Foundation

public enum HelperPalette {

    /// Tile colours by picker name.
    public static let colors: [String: Int] = [
        "red": 4_282_601_983,
        "orange-red": 4_251_333_119,
        "orange": 4_271_458_815,
        "yellow": 4_274_264_319,
        "green": 4_292_093_695,
        "teal": 431_817_727,
        "light-blue": 1_440_408_063,
        "blue": 463_140_863,
        "indigo": 946_986_751,
        "purple": 2_071_128_575,
        "lavender": 3_679_049_983,
        "pink": 3_980_825_855,
        "grey": 255,
        "sage": 3_031_607_807,
        "tan": 2_846_468_607,
    ]

    /// Each fleet tool's colour.
    public static let toolColors: [String: String] = [
        "agenda": "red",
        "ask": "purple",
        "browse": "light-blue",
        "mac": "teal",
        "memos": "orange",
        "notes": "yellow",
        "settings": "blue",
        "whatsapp": "green",
    ]

    /// The default glyph, as Shortcuts gives a built file.
    public static let defaultGlyph = 59511

    /// The glyphs Shortcuts can draw.
    public static var glyphs: Set<Int> { Set(HelperGlyphs.symbols.keys) }

    /// The SF Symbol a glyph shows.
    public static func symbol(_ glyph: Int) -> String? { HelperGlyphs.symbols[glyph] }

    /// The icon as a shortcut file stores it; `nil` for an unknown colour.
    static func recipeIcon(_ icon: HelperIcon) -> RecipeIcon? {
        colors[icon.color].map { RecipeIcon(color: $0, glyph: icon.glyph) }
    }
}
