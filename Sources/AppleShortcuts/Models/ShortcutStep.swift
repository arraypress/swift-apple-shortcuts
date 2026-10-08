//
//  ShortcutStep.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One action in a shortcut, as stored.
public struct ShortcutStep: Sendable, Equatable, Codable {

    /// The action's identifier: `is.workflow.actions.gettext`.
    public let action: String

    /// What the catalogue calls it — "Text" — when the catalogue knows it.
    public let name: String?

    /// The parameters, exactly as stored, minus the step's own `UUID`.
    public let parameters: [String: PlistValue]

    /// A step from its parts.
    public init(action: String, name: String? = nil, parameters: [String: PlistValue] = [:]) {
        self.action = action
        self.name = name
        self.parameters = parameters
    }
}
