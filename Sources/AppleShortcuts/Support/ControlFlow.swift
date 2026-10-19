//
//  ControlFlow.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  Shortcuts' own control-flow actions, which its action catalogue does not
//  list. Measured: `is.workflow.actions.conditional` (If / Otherwise / End If)
//  is in no table of Tools-prod.sqlite on macOS 27, though every shortcut
//  with an If uses it. Without this, a recipe with a branch was refused as
//  an unknown action.
//

import Foundation

enum ControlFlow {

    /// The If action. One step per part, tied by `GroupingIdentifier`:
    /// `WFControlFlowMode` 0 opens (with the condition), 1 is Otherwise,
    /// 2 is End If. `WFCondition` 4 is "is", 5 "is not", 100 "has any value",
    /// 101 "does not have any value"; the text compared is
    /// `WFConditionalActionString`, the input
    /// `{"Type": "Variable", "Variable": <attachment>}`.
    static let conditional = CatalogAction(
        id: "is.workflow.actions.conditional", name: "If", summary: "Runs the steps inside it only when a condition holds.",
        app: "com.apple.shortcuts", appName: "Shortcuts", kind: "action", outputName: "If Result",
        parameters: [
            CatalogParameter(key: "GroupingIdentifier", type: "string"),
            CatalogParameter(key: "WFControlFlowMode", type: "number"),
            CatalogParameter(key: "WFCondition", type: "number"),
            CatalogParameter(key: "WFConditionalActionString", type: "string"),
            CatalogParameter(key: "WFNumberValue", type: "number"),
            CatalogParameter(key: "WFInput", type: "com.apple.shortcuts.WFContentItem"),
        ]
    )

    /// Every control-flow action, by identifier.
    static let actions: [String: CatalogAction] = [conditional.id: conditional]
}
