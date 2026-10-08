//
//  PlistValue.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A property-list value, as a Swift value.
///
/// A shortcut is a property list, and an action's parameters can be any
/// shape — a string, a number, a dictionary describing a variable. This
/// carries them exactly, and encodes to JSON as the plain value rather than as
/// a tagged enum, so `{"WFVolume": 0.5}` reads the way it was written.
public enum PlistValue: Sendable, Equatable, Hashable {
    case string(String)
    case integer(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
    case data(Data)
    case array([PlistValue])
    case dictionary([String: PlistValue])
}
