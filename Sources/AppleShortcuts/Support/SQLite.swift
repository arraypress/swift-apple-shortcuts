//
//  SQLite.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  A read-only door onto a SQLite file. Deliberately small.
//

import Foundation
import SQLite3

/// The smallest SQLite wrapper that can run this library's queries.
///
/// The same shape as swift-apple-mail's, for the same reason: everything here
/// reads a store a running app owns — the Shortcuts library and its action
/// catalogue — and the whole surface worth auditing is one file. It opens
/// read-only, binds parameters rather than pasting them into SQL, and has no
/// code path that writes.
final class SQLiteDatabase {

    private let handle: OpaquePointer

    /// Opens a database for reading and nothing else.
    ///
    /// `SQLITE_OPEN_READONLY` on the live file, with no copy, so the
    /// write-ahead log is seen: a shortcut added a moment ago is still in the
    /// `-wal`, and a copied file would not have it.
    init(path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ShortcutsError.readFailed("no file at \(path)")
        }

        var pointer: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI
        // The URI form carries the mode explicitly, so a future edit cannot
        // widen the open by dropping a flag.
        let uri = "file:\(path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path)?mode=ro"
        let result = sqlite3_open_v2(uri, &pointer, flags, nil)

        guard result == SQLITE_OK, let pointer else {
            let message = pointer.map { String(cString: sqlite3_errmsg($0)) } ?? "code \(result)"
            if let pointer { sqlite3_close_v2(pointer) }
            // SQLITE_CANTOPEN on a file that plainly exists is what a privacy
            // refusal looks like from here.
            if result == SQLITE_CANTOPEN { throw ShortcutsError.notPermitted(path) }
            throw ShortcutsError.readFailed(message)
        }
        handle = pointer
    }

    deinit { sqlite3_close_v2(handle) }

    /// Runs a query, handing each row to `row`.
    ///
    /// - Parameters:
    ///   - sql: The statement. Values belong in `parameters`, never here.
    ///   - parameters: Bound in order, standing in for each `?`.
    func query(_ sql: String, _ parameters: [SQLiteValue] = [], row: (Row) -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw ShortcutsError.readFailed(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(statement) }

        for (offset, parameter) in parameters.enumerated() {
            let index = Int32(offset + 1)
            switch parameter {
            case .integer(let value):
                sqlite3_bind_int64(statement, index, value)
            case .text(let value):
                // SQLITE_TRANSIENT: SQLite copies the bytes rather than
                // holding a pointer into a Swift string about to go away.
                sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            row(Row(statement: statement))
        }
    }

    /// One row of a result.
    struct Row {

        let statement: OpaquePointer

        /// An integer column.
        func integer(_ index: Int32) -> Int64 { sqlite3_column_int64(statement, index) }

        /// A real column, or `nil` for NULL — Core Data keeps dates this way,
        /// as seconds since 2001.
        func double(_ index: Int32) -> Double? {
            sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : sqlite3_column_double(statement, index)
        }

        /// A text column, or `nil` for NULL.
        func text(_ index: Int32) -> String? {
            guard let bytes = sqlite3_column_text(statement, index) else { return nil }
            return String(cString: bytes)
        }

        /// A blob column, or `nil` for NULL.
        func data(_ index: Int32) -> Data? {
            guard let bytes = sqlite3_column_blob(statement, index) else { return nil }
            return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, index)))
        }
    }
}

/// A value bound into a query.
enum SQLiteValue {
    case integer(Int64)
    case text(String)
}
