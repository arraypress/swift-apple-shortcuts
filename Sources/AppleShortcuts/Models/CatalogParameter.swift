//
//  CatalogParameter.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One parameter of a catalogue action.
public struct CatalogParameter: Sendable, Equatable, Codable {

    /// The key a shortcut file stores it under: `WFVolume`.
    public let key: String

    /// What Shortcuts labels it: "Volume".
    public let name: String?

    /// The catalogue's note on it, when there is one.
    public let description: String?

    /// Its type: `number`, `bool`, `date`, `string`, or the identifier of
    /// an enumeration or a content type.
    public let type: String?

    /// The values an enumeration accepts, by the identifier a shortcut file
    /// stores: Set Volume's setting takes `Media`, `Ringtone`, …
    public let choices: [String]

    /// A parameter from its parts.
    public init(key: String, name: String? = nil, description: String? = nil,
                type: String? = nil, choices: [String] = []) {
        self.key = key
        self.name = name
        self.description = description
        self.type = type
        self.choices = choices
    }
}
