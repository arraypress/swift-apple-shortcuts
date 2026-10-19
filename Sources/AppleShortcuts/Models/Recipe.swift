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

    /// Its icon; `nil` is Shortcuts' default, a red tile.
    public let icon: RecipeIcon?

    /// When set, a run with no input stops with this message instead of
    /// asking for input (`WFWorkflowNoInputBehaviorShowError`).
    public let noInputError: String?

    /// A recipe from its parts.
    public init(name: String, actions: [RecipeStep], icon: RecipeIcon? = nil, noInputError: String? = nil) {
        self.name = name
        self.actions = actions
        self.icon = icon
        self.noInputError = noInputError
    }
}
