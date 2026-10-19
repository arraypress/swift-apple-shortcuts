//
//  MacAvailability.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Whether an action in the catalogue can be used in a shortcut on this Mac.
///
/// MEASURED on macOS 27.0.1 (2026-10-19), importing 21 built helpers:
/// - every action whose `Tools.visibilityFlags` lacked bit 4 (value 4) was
///   refused at import, the whole shortcut with it: "This shortcut can't be
///   imported because it contains features not supported on this device"
///   (Reminders' Add or Remove Tags, Enable Stage Manager, Add or Remove Note
///   Lock, Journal's Create Entry and Search, Safari's tab group actions,
///   Clock's Find/Pause/Resume/Cancel Timer, Books' audiobook sleep timer);
///   every action with the bit was imported.
/// - an action whose `Tools.requirements` lists platforms without 3 imported,
///   then showed "This action is not supported on Mac" in the editor and
///   failed the run (Set Low Power Mode: platforms 7, 1, 2, 5). Put Display
///   to Sleep lists only 3, so 3 is the Mac. An empty list restricts nothing.
public enum MacAvailability: String, Sendable, Equatable, Codable {
    /// Imports and runs.
    case runs
    /// The Mac's Shortcuts refuses a shortcut containing it.
    case refusedAtImport = "refused_at_import"
    /// Imports, but cannot run on a Mac.
    case notOnMac = "not_on_mac"
}
