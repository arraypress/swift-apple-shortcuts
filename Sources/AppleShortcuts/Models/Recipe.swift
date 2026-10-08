//
//  Recipe.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A shortcut, written as data, before it is built.
///
/// ```json
/// {
///   "name": "Quiet Hours",
///   "actions": [
///     {"action": "is.workflow.actions.setvolume", "parameters": {"WFVolume": 0.2}},
///     {"action": "is.workflow.actions.gettext", "parameters": {"WFTextActionText": "Volume down. You said: $input"}}
///   ]
/// }
/// ```
///
/// Two tokens may appear in any string parameter: `$input`, whatever the
/// shortcut was run with, and `$previous`, the output of the step before.
/// `$$` is a literal dollar sign.
public struct Recipe: Sendable, Equatable, Codable {

    /// The shortcut's name, which is what it will run by once added.
    public let name: String

    /// The steps, in order.
    public let actions: [RecipeStep]

    /// A recipe from its parts.
    public init(name: String, actions: [RecipeStep]) {
        self.name = name
        self.actions = actions
    }
}
