//
//  Helper+Codable.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  A helper file, read strictly: an unknown key anywhere refuses the file.
//

import Foundation

extension Helper: Codable {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id, tool, title, description, version, icon, input, output, steps, notes, replaces, install
        case legacyName = "name"
        case experimental, patience, timeout
    }

    public init(from decoder: Decoder) throws {
        try StrictKeys.check(decoder, allowed: CodingKeys.allCases.map(\.rawValue), in: "a helper")
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            tool: try c.decode(String.self, forKey: .tool),
            title: try c.decode(String.self, forKey: .title),
            description: try c.decode(String.self, forKey: .description),
            version: try c.decode(Int.self, forKey: .version),
            icon: try c.decode(HelperIcon.self, forKey: .icon),
            input: try c.decodeIfPresent([HelperField].self, forKey: .input) ?? [],
            output: try c.decode(HelperOutput.self, forKey: .output),
            steps: try c.decode([RecipeStep].self, forKey: .steps),
            notes: try c.decodeIfPresent([String].self, forKey: .notes) ?? [],
            replaces: try c.decodeIfPresent([String].self, forKey: .replaces) ?? [],
            install: try c.decode(String.self, forKey: .install),
            legacyName: try c.decodeIfPresent(String.self, forKey: .legacyName),
            experimental: try c.decodeIfPresent(Bool.self, forKey: .experimental) ?? false,
            patience: try c.decodeIfPresent(Double.self, forKey: .patience) ?? 5,
            timeout: try c.decodeIfPresent(Double.self, forKey: .timeout) ?? 30
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(tool, forKey: .tool)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(version, forKey: .version)
        try c.encode(icon, forKey: .icon)
        try c.encode(input, forKey: .input)
        try c.encode(output, forKey: .output)
        try c.encode(steps, forKey: .steps)
        try c.encode(notes, forKey: .notes)
        try c.encode(replaces, forKey: .replaces)
        try c.encode(install, forKey: .install)
        try c.encodeIfPresent(legacyName, forKey: .legacyName)
        if experimental { try c.encode(true, forKey: .experimental) }
        try c.encode(patience, forKey: .patience)
        try c.encode(timeout, forKey: .timeout)
    }
}

extension HelperField {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case name, type, required, description, choices
    }

    public init(from decoder: Decoder) throws {
        try StrictKeys.check(decoder, allowed: CodingKeys.allCases.map(\.rawValue), in: "a helper input field")
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: try c.decode(String.self, forKey: .name),
                  type: try c.decode(HelperFieldType.self, forKey: .type),
                  required: try c.decodeIfPresent(Bool.self, forKey: .required) ?? true,
                  description: try c.decode(String.self, forKey: .description),
                  choices: try c.decodeIfPresent([String].self, forKey: .choices) ?? [])
    }
}

extension HelperOutput {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case type, description
    }

    public init(from decoder: Decoder) throws {
        try StrictKeys.check(decoder, allowed: CodingKeys.allCases.map(\.rawValue), in: "a helper's output")
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(type: try c.decode(HelperOutputType.self, forKey: .type),
                  description: try c.decodeIfPresent(String.self, forKey: .description))
    }
}

extension HelperIcon {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case glyph, color
    }

    public init(from decoder: Decoder) throws {
        try StrictKeys.check(decoder, allowed: CodingKeys.allCases.map(\.rawValue), in: "a helper's icon")
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(glyph: try c.decode(Int.self, forKey: .glyph), color: try c.decode(String.self, forKey: .color))
    }
}
