//
//  SigningMode.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Who a signed shortcut file can be opened by.
///
/// Shortcuts opens only signed files, so a built shortcut is always signed.
/// The modes are the `shortcuts sign` command's own.
public enum SigningMode: String, Sendable, Equatable, Codable, CaseIterable {

    /// The signer, and people who have them as a contact. Signed on this Mac:
    /// **0.09 s**, measured. The default, because the usual reader of a built
    /// shortcut is the person who asked for it.
    case peopleWhoKnowMe = "people-who-know-me"

    /// Anyone. Goes through Apple's servers: **9 s**, measured, and needs a
    /// network.
    case anyone
}
