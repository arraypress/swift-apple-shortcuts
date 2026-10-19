//
//  HelperLint.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  What a shortcut's steps say that the Mac editor will not run as meant —
//  checked on a built recipe before it is offered, and on an installed helper
//  read back from the library, which holds the steps exactly as written.
//
//  Each rule is a MEASURED failure (macOS 27.0.1, 2026-10-19), seen in the
//  editor on helpers this library built:
//  - an If comparing text ("is", "is not", "contains", "begins with",
//    "ends with") with its text as a plain WFConditionalActionString showed an
//    empty value and "Please choose a value for each parameter in this
//    action", and every run of the shortcut failed with that message;
//  - a named variable inside a quantity (Start Timer's minutes:
//    WFQuantityFieldValue's Magnitude) showed as "Unknown Variable";
//  - a variable no earlier Set Variable names is dangling: the editor shows
//    "Unknown Variable" and the run gets nothing.
//  "has any value" / "does not have any value" Ifs (100, 101) carry no text
//  and ran as meant.
//

import Foundation

enum HelperLint {

    /// If conditions that compare against text.
    static let textConditions: Set<Int> = [4, 5, 8, 9, 99, 999]

    /// Actions that put something on screen: a helper runs in the background,
    /// and a dialog there waits on a person.
    static let showingActions: Set<String> = [
        "is.workflow.actions.showresult", "is.workflow.actions.alert", "is.workflow.actions.notification",
        "is.workflow.actions.previewdocument", "is.workflow.actions.showdefinition", "is.workflow.actions.ask",
        "is.workflow.actions.choosefromlist", "is.workflow.actions.choosefrommenu",
    ]

    /// Every problem in `steps`, one sentence each.
    static func problems(_ steps: [ShortcutStep]) -> [String] {
        var problems: [String] = []
        var defined = Set<String>()
        for (index, step) in steps.enumerated() {
            let at = "step \(index + 1) (\(step.action))"
            for name in variableNames(in: .dictionary(step.parameters)) where !defined.contains(name) {
                problems.append("\(at): uses the variable \(name) before any Set Variable names it")
            }
            if step.action == "is.workflow.actions.conditional", case .integer(0)? = step.parameters["WFControlFlowMode"] {
                if case .integer(let condition)? = step.parameters["WFCondition"], textConditions.contains(condition) {
                    problems.append("\(at): an If comparing text loses its text on the Mac (use \"has any value\" with one key per branch)")
                }
                if step.parameters["WFInput"] == nil { problems.append("\(at): an If with nothing to test") }
            }
            if showingActions.contains(step.action) {
                problems.append("\(at): shows something on screen — a helper must hand its answer back, not show it")
            }
            for flag in ["ShowWhenRun", "OpenWhenRun", "FollowUp"] {
                if case .bool(true)? = step.parameters[flag] {
                    problems.append("\(at): \(flag) is on — it opens a window and waits (MEASURED for Use Model's Follow Up)")
                }
            }
            if step.action == "is.workflow.actions.output", step.parameters["WFNoOutputSurfaceBehavior"] != .string("Do Nothing") {
                problems.append("\(at): Stop and Output without \"Do Nothing\" shows the result when run by hand")
            }
            if asks(.dictionary(step.parameters)) {
                problems.append("\(at): a parameter is Ask Each Time — a background run would wait on a person")
            }
            if containsQuantityVariable(.dictionary(step.parameters)) {
                problems.append("\(at): a variable inside a quantity shows as Unknown Variable on the Mac")
            }
            if step.action == "is.workflow.actions.setvariable", case .string(let name)? = step.parameters["WFVariableName"] {
                defined.insert(name)
            }
        }
        return problems
    }

    /// The behaviour's name in `ZNOINPUTBEHAVIORDATA`, a property list
    /// `{Name, Parameters}` (WorkflowKit's WFNoInputBehaviorSerializedRepresentation).
    static func noInputBehaviorName(_ data: Data) -> String? {
        (try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])?["Name"] as? String
    }

    /// The behaviour every helper with input must have.
    static let stopsOnNoInput = "WFWorkflowNoInputBehaviorShowError"

    /// Whether a value asks the person: an `{"Type": "Ask"}` attachment.
    static func asks(_ value: PlistValue) -> Bool {
        switch value {
        case .dictionary(let dictionary):
            if case .string("Ask")? = dictionary["Type"] { return true }
            return dictionary.values.contains(where: asks)
        case .array(let array): return array.contains(where: asks)
        default: return false
        }
    }

    /// Named variables a value refers to: `{"Type": "Variable", "VariableName": x}` at any depth.
    static func variableNames(in value: PlistValue) -> [String] {
        switch value {
        case .dictionary(let dictionary):
            var names: [String] = []
            if case .string("Variable")? = dictionary["Type"], case .string(let name)? = dictionary["VariableName"] { names.append(name) }
            for (_, inner) in dictionary.sorted(by: { $0.key < $1.key }) { names += variableNames(in: inner) }
            return names
        case .array(let array): return array.flatMap(variableNames)
        default: return []
        }
    }

    /// Whether a WFQuantityFieldValue's Magnitude is a variable.
    static func containsQuantityVariable(_ value: PlistValue) -> Bool {
        switch value {
        case .dictionary(let dictionary):
            if case .string("WFQuantityFieldValue")? = dictionary["WFSerializationType"],
               case .dictionary(let inner)? = dictionary["Value"], let magnitude = inner["Magnitude"], !variableNames(in: magnitude).isEmpty {
                return true
            }
            return dictionary.values.contains(where: containsQuantityVariable)
        case .array(let array): return array.contains(where: containsQuantityVariable)
        default: return false
        }
    }

    /// The problems in a helper as built — what its recipe would store.
    static func problems(of helper: Helper) -> [String] {
        let context = RecipeEncoding.Context(outputName: { _ in nil }, isTextParameter: { _, _ in false })
        let workflow = RecipeEncoding.workflow(helper.recipe, context: context)
        let actions = (workflow["WFWorkflowActions"] as? [[String: Any]]) ?? []
        return problems(actions.compactMap(StepDecoding.step))
    }
}
