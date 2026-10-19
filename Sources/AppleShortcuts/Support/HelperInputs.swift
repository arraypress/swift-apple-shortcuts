//
//  HelperInputs.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  A run's input, checked against the helper's fields before anything runs.
//  A shortcut handed a misspelt key reads nothing for it and carries on.
//

import Foundation

enum HelperInputs {

    /// The input as sorted-key JSON, or a refusal naming what is wrong.
    static func encode(_ values: [String: PlistValue], for helper: Helper) throws -> Data {
        if let problem = problem(values, for: helper) { throw HelperError.invalidInput(id: helper.id, reason: problem) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(values)
    }

    /// What is wrong with `values`, or `nil`.
    static func problem(_ values: [String: PlistValue], for helper: Helper) -> String? {
        let fields = Dictionary(uniqueKeysWithValues: helper.input.map { ($0.name, $0) })
        if let unknown = values.keys.sorted().first(where: { fields[$0] == nil }) {
            return "it takes no \"\(unknown)\"" + (fields.isEmpty ? "" : " (it takes \(fields.keys.sorted().joined(separator: ", ")))")
        }
        for field in helper.input {
            guard let value = values[field.name] else {
                if field.required { return "\"\(field.name)\" is required" }
                continue
            }
            switch (field.type, value) {
            case (.string, .string(let text)):
                if !field.choices.isEmpty, !field.choices.contains(text) {
                    return "\"\(field.name)\" is one of \(field.choices.joined(separator: ", ")), not \(text)"
                }
            case (.bool, .bool), (.number, .integer), (.number, .double), (.list, .array): continue
            default: return "\"\(field.name)\" is a \(field.type.rawValue)"
            }
        }
        return nil
    }
}
