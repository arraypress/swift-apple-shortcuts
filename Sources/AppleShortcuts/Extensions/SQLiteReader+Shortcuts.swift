//
//  SQLiteReader+Shortcuts.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  Shortcuts' stores — the library and the action catalogue — are read
//  through swift-sqlite-reader, read-only in place: a shortcut added a
//  moment ago is still in the `-wal`, and a copied file would not have it.
//  Its errors are reported as ShortcutsError, so callers and messages stay
//  the same.
//

import Foundation
import SQLiteReader

extension ShortcutsError {

    /// This library's error for a reader's.
    init(_ error: SQLiteReaderError) {
        switch error {
        case .notFound(let path): self = .readFailed("no file at \(path)")
        case .permissionDenied(let path): self = .notPermitted(path)
        case .unreadable(_, let reason): self = .readFailed(reason)
        }
    }
}

extension SQLiteReader {

    /// Opens one of Shortcuts' stores for reading and nothing else.
    static func shortcutsStore(_ path: String) throws(ShortcutsError) -> SQLiteReader {
        do { return try SQLiteReader(path: URL(fileURLWithPath: path), opening: .readOnly) } catch { throw ShortcutsError(error) }
    }

    /// Runs a query, handing each row to `row`; a failure is a ``ShortcutsError``.
    ///
    /// - Parameters:
    ///   - sql: The statement. Values belong in `bindings`, never here.
    ///   - bindings: Bound in order, standing in for each `?`.
    func read(_ sql: String, _ bindings: [SQLiteValue] = [], row: (SQLiteRow) -> Void) throws(ShortcutsError) {
        do { try query(sql, bindings, row: row) } catch { throw ShortcutsError(error) }
    }
}
