import Foundation
import SQLite3

let SQLITE_TRANSIENT = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)

public enum DatabaseError: Error, CustomStringConvertible {
    case openFailed(Int32, String)
    case prepareFailed(String, Int32, String)
    case stepFailed(String, Int32, String)
    case constraintFailed(String)

    public var description: String {
        switch self {
        case .openFailed(let code, let msg): return "sqlite open (\(code)): \(msg)"
        case .prepareFailed(let sql, let code, let msg): return "sqlite prepare (\(code)) `\(sql)`: \(msg)"
        case .stepFailed(let sql, let code, let msg): return "sqlite step (\(code)) `\(sql)`: \(msg)"
        case .constraintFailed(let msg): return "sqlite constraint: \(msg)"
        }
    }
}

/// A serial-access wrapper around a single sqlite3 connection.
public final class Database: @unchecked Sendable {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "WhatNowCore.Database")

    public init(url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var handle: OpaquePointer?
        let result = sqlite3_open_v2(
            url.path,
            &handle,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard result == SQLITE_OK, let handle else {
            throw DatabaseError.openFailed(result, String(cString: sqlite3_errmsg(handle)))
        }
        self.db = handle
        try runSQL("PRAGMA foreign_keys = ON")
        try runSQL("PRAGMA journal_mode = WAL")
        try migrate()
    }

    /// In-memory connection for tests.
    public init(inMemory: Void = ()) throws {
        var handle: OpaquePointer?
        let result = sqlite3_open_v2(":memory:", &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard result == SQLITE_OK, let handle else {
            throw DatabaseError.openFailed(result, String(cString: sqlite3_errmsg(handle)))
        }
        self.db = handle
        try migrate()
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    public static func defaultURL() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("WhatNow", isDirectory: true)
        return dir.appendingPathComponent("tasks.db", isDirectory: false)
    }

    // MARK: - Sync access

    public func sync<T>(_ work: (OpaquePointer) throws -> T) rethrows -> T {
        try queue.sync {
            try work(db!)
        }
    }

    /// Run a SQL statement that does not return rows.
    public func runSQL(_ sql: String) throws {
        try sync { handle in
            var errmsg: UnsafeMutablePointer<CChar>?
            let result = sqlite3_exec(handle, sql, nil, nil, &errmsg)
            if result != SQLITE_OK {
                let message = errmsg.map { String(cString: $0) } ?? "unknown"
                if let errmsg { sqlite3_free(errmsg) }
                throw DatabaseError.stepFailed(sql, result, message)
            }
        }
    }

    // MARK: - Migrations

    private func migrate() throws {
        try runSQL("""
        CREATE TABLE IF NOT EXISTS tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            details TEXT,
            due_at REAL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            completed_at REAL
        )
        """)
        try runSQL("CREATE INDEX IF NOT EXISTS idx_tasks_updated_at ON tasks(updated_at)")
    }
}

// MARK: - Statement helpers

public final class Statement {
    let handle: OpaquePointer
    let sql: String
    let db: OpaquePointer

    init(db: OpaquePointer, sql: String) throws {
        var stmt: OpaquePointer?
        let result = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard result == SQLITE_OK, let stmt else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.prepareFailed(sql, result, msg)
        }
        self.handle = stmt
        self.sql = sql
        self.db = db
    }

    deinit { sqlite3_finalize(handle) }

    public func bind(_ index: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(handle, index, value, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(handle, index)
        }
    }

    public func bind(_ index: Int32, _ value: Date?) {
        if let value {
            sqlite3_bind_double(handle, index, value.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(handle, index)
        }
    }

    public func bind(_ index: Int32, double: Double) {
        sqlite3_bind_double(handle, index, double)
    }

    public func step() throws -> Bool {
        let result = sqlite3_step(handle)
        switch result {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        case SQLITE_CONSTRAINT:
            throw DatabaseError.constraintFailed(String(cString: sqlite3_errmsg(db)))
        default:
            throw DatabaseError.stepFailed(sql, result, String(cString: sqlite3_errmsg(db)))
        }
    }

    public func text(_ column: Int32) -> String? {
        guard let c = sqlite3_column_text(handle, column) else { return nil }
        return String(cString: c)
    }

    public func date(_ column: Int32) -> Date? {
        if sqlite3_column_type(handle, column) == SQLITE_NULL { return nil }
        return Date(timeIntervalSince1970: sqlite3_column_double(handle, column))
    }

    public func reset() {
        sqlite3_reset(handle)
        sqlite3_clear_bindings(handle)
    }
}
