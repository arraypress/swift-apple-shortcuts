//
//  PlistValue+Codable.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  A plist value as the plain JSON value, not as a tagged enum.
//

import Foundation

extension PlistValue: Codable {

    /// Reads any JSON value.
    ///
    /// Whole numbers become integers and the rest doubles: `0.5` is a volume,
    /// `3` a count, and JSON does not say which it meant any other way.
    /// Dates and data have no JSON form and arrive as strings.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let integer = try? container.decode(Int.self) {
            self = .integer(integer)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([PlistValue].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String: PlistValue].self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "not a property-list value")
        }
    }

    /// Writes the plain value. A date is ISO 8601; data is base64.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string): try container.encode(string)
        case .integer(let integer): try container.encode(integer)
        case .double(let double): try container.encode(double)
        case .bool(let bool): try container.encode(bool)
        case .date(let date): try container.encode(ISO8601DateFormatter().string(from: date))
        case .data(let data): try container.encode(data.base64EncodedString())
        case .array(let array): try container.encode(array)
        case .dictionary(let dictionary): try container.encode(dictionary)
        }
    }
}
