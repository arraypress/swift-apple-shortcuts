//
//  FileNaming.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// File names for built shortcuts.
enum FileNaming {

    /// `Quiet Hours.shortcut` for "Quiet Hours".
    ///
    /// The name is kept as written wherever a file system allows it, because
    /// Shortcuts names the added shortcut after the file: a slash or a colon
    /// becomes a dash, leading dots are dropped so the file is not hidden,
    /// and nothing else changes.
    static func fileName(for name: String) -> String {
        var cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespaces)
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        return (cleaned.isEmpty ? "Shortcut" : cleaned) + ".shortcut"
    }
}
