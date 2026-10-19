//
//  HelperError.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Why a helper was not run or offered. Every case is raised BEFORE anything
/// runs.
public enum HelperError: Error, Equatable, Sendable, LocalizedError {

    /// The helper is not runnable as it stands. Carries its status, so the
    /// caller can say exactly why and what to do.
    case notReady(HelperStatus)

    /// The input does not fit the helper's fields.
    case invalidInput(id: String, reason: String)

    /// A helper file breaks the catalogue's rules.
    case invalidCatalogue(String)

    /// A sentence a person can act on.
    public var errorDescription: String? {
        switch self {
        case .notReady(let status): HelperText.problem(status)
        case .invalidInput(let id, let reason): "Input for \(id) refused: \(reason)"
        case .invalidCatalogue(let reason): "The helper catalogue is broken: \(reason)"
        }
    }

    /// The command that puts it right, when there is one.
    public var remedy: String? {
        switch self {
        case .notReady(let status): HelperText.remedy(status)
        case .invalidInput, .invalidCatalogue: nil
        }
    }
}
