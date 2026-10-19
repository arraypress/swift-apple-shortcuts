//
//  Tokens.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  `$input` and `$previous` in a recipe, and what Shortcuts stores for them.
//

import Foundation

/// The variables a recipe can use, and their encoding in a shortcut file:
/// `$input`, `$previous`, and `${name}` for a variable a Set Variable step
/// named — the same `{"Type": "Variable", "VariableName": name}` agenda's
/// tag helper wrote by hand, and Shortcuts ran.
///
/// Shortcuts stores a variable two ways, and which one depends on where it
/// goes. In a TEXT parameter — the catalogue types `string` and
/// `attributedString` — it is a token string: the text with U+FFFC standing
/// in for each variable, and the variables listed by the UTF-16 range they
/// occupy. In any other parameter — content, a file, a placemark — a variable
/// that is the whole value is an attachment.
///
/// Both checked against Shortcuts: the token string for `$previous` is byte
/// for byte what Shortcuts itself wrote into a step it added, and a built
/// shortcut using `$input` then `$previous` ran and printed what it should.
enum Tokens {

    /// A piece of a written string.
    enum Segment: Equatable {
        /// Literal text.
        case text(String)
        /// Whatever the shortcut was run with.
        case input
        /// The output of the step before.
        case previous
        /// A named variable, set earlier by Set Variable: `${name}`.
        case variable(String)
    }

    /// The object-replacement character Shortcuts puts where a variable sits.
    static let placeholder = "\u{FFFC}"

    /// Catalogue types whose parameters hold text, and so take token strings.
    static let textTypes: Set<String> = ["string", "attributedString"]

    /// Splits a string into text and variables.
    ///
    /// `$input` and `$previous` are variables; `$$` is a dollar sign; any
    /// other `$` is left as written, so "$5 off" survives.
    static func segments(_ string: String) -> [Segment] {
        var segments: [Segment] = []
        var text = ""
        var rest = Substring(string)

        func flush() {
            if !text.isEmpty { segments.append(.text(text)); text = "" }
        }

        while let first = rest.first {
            if rest.hasPrefix("$$") {
                text.append("$")
                rest = rest.dropFirst(2)
            } else if rest.hasPrefix("$input") {
                flush()
                segments.append(.input)
                rest = rest.dropFirst(6)
            } else if rest.hasPrefix("$previous") {
                flush()
                segments.append(.previous)
                rest = rest.dropFirst(9)
            } else if rest.hasPrefix("${"), let close = rest.firstIndex(of: "}"),
                      case let name = rest[rest.index(rest.startIndex, offsetBy: 2)..<close],
                      !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
                flush()
                segments.append(.variable(String(name)))
                rest = rest[rest.index(after: close)...]
            } else {
                text.append(first)
                rest = rest.dropFirst()
            }
        }
        flush()
        return segments
    }

    /// Whether a string uses any variable.
    static func usesVariables(_ string: String) -> Bool {
        segments(string).contains { !isText($0) }
    }

    /// Whether a segment is literal text.
    static func isText(_ segment: Segment) -> Bool {
        if case .text = segment { return true }
        return false
    }

    /// The attachment dictionary for one variable.
    ///
    /// - Parameter previous: The step before — its UUID and output name — for
    ///   `$previous`. `nil` when there is no step before, which validation
    ///   refuses before this is ever reached.
    static func attachment(_ segment: Segment, previous: (uuid: String, name: String)?) -> [String: Any] {
        switch segment {
        case .input:
            return ["Type": "ExtensionInput"]
        case .previous:
            guard let previous else { return ["Type": "ExtensionInput"] }
            return ["Type": "ActionOutput", "OutputUUID": previous.uuid, "OutputName": previous.name]
        case .variable(let name):
            return ["Type": "Variable", "VariableName": name]
        case .text:
            return [:]
        }
    }

    /// What a string parameter is stored as.
    ///
    /// - Parameters:
    ///   - isTextParameter: Whether the parameter holds text, from its
    ///     catalogue type.
    /// - Returns: The string unchanged when it has no variables; otherwise a
    ///   token string or an attachment.
    static func encode(_ string: String, isTextParameter: Bool,
                       previous: (uuid: String, name: String)?) -> Any {
        let parts = segments(string)
        guard parts.contains(where: { !isText($0) }) else {
            return parts.map { if case .text(let t) = $0 { t } else { "" } }.joined()
        }

        if !isTextParameter, parts.count == 1, let only = parts.first {
            return ["Value": attachment(only, previous: previous),
                    "WFSerializationType": "WFTextTokenAttachment"]
        }

        var text = ""
        var ranges: [String: Any] = [:]
        for part in parts {
            if case .text(let literal) = part {
                text += literal
            } else {
                // Ranges count UTF-16 units, as NSString does: an emoji
                // before a variable is two units, not one Character.
                ranges["{\(text.utf16.count), 1}"] = attachment(part, previous: previous)
                text += placeholder
            }
        }
        return ["Value": ["string": text, "attachmentsByRange": ranges],
                "WFSerializationType": "WFTextTokenString"]
    }
}
