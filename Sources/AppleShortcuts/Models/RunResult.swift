//
//  RunResult.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a shortcut handed back.
public struct RunResult: Sendable, Equatable {

    /// The output, as bytes. Empty for a shortcut with no output.
    public let output: Data

    /// How long the run took, in seconds.
    ///
    /// Worth keeping: a shortcut that took 18 s did not run slowly — it
    /// waited for somebody to answer Shortcuts' output prompt.
    public let duration: Double

    /// A result from its parts.
    public init(output: Data, duration: Double) {
        self.output = output
        self.duration = duration
    }
}
