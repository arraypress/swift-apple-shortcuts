//
//  PlistValueCoding.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  Property-list values in and out of Foundation's object graph.
//

import Foundation

/// Converting between ``PlistValue`` and what `PropertyListSerialization`
/// reads and writes.
enum PlistValueCoding {

    /// A Foundation object for writing into a property list.
    static func object(_ value: PlistValue) -> Any {
        switch value {
        case .string(let string): return string
        case .integer(let integer): return integer
        case .double(let double): return double
        case .bool(let bool): return bool
        case .date(let date): return date
        case .data(let data): return data
        case .array(let array): return array.map(object)
        case .dictionary(let dictionary): return dictionary.mapValues(object)
        }
    }

    /// A value from a Foundation object, or `nil` for anything a property
    /// list cannot hold.
    ///
    /// Booleans are checked before numbers: `NSNumber` carries both, and a
    /// `true` read as the integer 1 would be written back as a number — which
    /// Shortcuts reads as a different parameter value.
    static func value(_ object: Any) -> PlistValue? {
        switch object {
        case let number as NSNumber where CFGetTypeID(number) == CFBooleanGetTypeID():
            return .bool(number.boolValue)
        case let number as NSNumber:
            return CFNumberIsFloatType(number) ? .double(number.doubleValue) : .integer(number.intValue)
        case let string as String:
            return .string(string)
        case let date as Date:
            return .date(date)
        case let data as Data:
            return .data(data)
        case let array as [Any]:
            return .array(array.compactMap(value))
        case let dictionary as [String: Any]:
            return .dictionary(dictionary.compactMapValues(value))
        default:
            return nil
        }
    }
}
