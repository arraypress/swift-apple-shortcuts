//
//  CatalogAction.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// An action this Mac can put in a shortcut.
///
/// From Shortcuts' own index of every action every installed app offers —
/// 2,094 of them from 89 apps on the Mac this was built on. The identifier is
/// what a shortcut file names the action by, so a ``Recipe`` built from these
/// is a shortcut Shortcuts will open.
public struct CatalogAction: Sendable, Equatable, Codable {

    /// What a shortcut file names it by: `is.workflow.actions.setvolume`.
    public let id: String

    /// What Shortcuts shows: "Set Volume".
    public let name: String

    /// What it does, in the catalogue's words.
    public let summary: String?

    /// The bundle identifier of the app that offers it.
    public let app: String

    /// The app's name, when the catalogue has one.
    public let appName: String?

    /// How the action is implemented: `action` (Shortcuts' own),
    /// `appIntent`, `siriIntent` or `flowTool`.
    public let kind: String

    /// What its output is called when a later step uses it — "Text",
    /// "Maps URL". `nil` for an action with no output.
    public let outputName: String?

    /// What it takes.
    public let parameters: [CatalogParameter]

    /// Whether a shortcut on this Mac can use it.
    public let mac: MacAvailability

    /// An action from its parts. ``ActionCatalog`` reads real ones.
    public init(
        id: String,
        name: String,
        summary: String? = nil,
        app: String,
        appName: String? = nil,
        kind: String,
        outputName: String? = nil,
        parameters: [CatalogParameter] = [],
        mac: MacAvailability = .runs
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.app = app
        self.appName = appName
        self.kind = kind
        self.outputName = outputName
        self.parameters = parameters
        self.mac = mac
    }
}
