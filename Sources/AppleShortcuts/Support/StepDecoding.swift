//
//  StepDecoding.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  A stored shortcut's actions, out of the blob they are kept in.
//

import Foundation

/// Reading the action list Shortcuts stores per shortcut.
///
/// `ZSHORTCUTACTIONS.ZDATA` is a binary property list: an array of
/// `{WFWorkflowActionIdentifier, WFWorkflowActionParameters}` — the same shape
/// as a shortcut file's `WFWorkflowActions`, checked against a shortcut built
/// by this library, which came back exactly as written.
enum StepDecoding {

    /// The steps in a stored action list.
    static func steps(from data: Data) throws -> [ShortcutStep] {
        let object: Any
        do {
            object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        } catch {
            throw ShortcutsError.readFailed("a stored shortcut is not a property list: \(error.localizedDescription)")
        }
        guard let actions = object as? [[String: Any]] else {
            throw ShortcutsError.readFailed("a stored shortcut is not a list of actions")
        }
        return actions.compactMap(step)
    }

    /// One step, or `nil` for an entry with no identifier.
    ///
    /// The step's own `UUID` is dropped: it is how steps refer to one
    /// another inside the file, and means nothing to a reader.
    static func step(_ action: [String: Any]) -> ShortcutStep? {
        guard let id = action["WFWorkflowActionIdentifier"] as? String else { return nil }
        var parameters = (action["WFWorkflowActionParameters"] as? [String: Any] ?? [:])
            .compactMapValues(PlistValueCoding.value)
        parameters["UUID"] = nil
        return ShortcutStep(action: id, parameters: parameters)
    }
}
