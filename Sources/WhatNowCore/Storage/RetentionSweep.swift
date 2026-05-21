import Foundation
import SQLite3

public struct RetentionSweep: Sendable {
    private let database: Database
    private let repository: TaskRepository
    private let clock: @Sendable () -> Date

    public init(database: Database, repository: TaskRepository, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.database = database
        self.repository = repository
        self.clock = clock
    }

    /// Hard-delete every row older than the retention window. Returns the number purged.
    @discardableResult
    public func run() throws -> Int {
        let cutoff = clock().addingTimeInterval(-retentionWindow)
        let deleted: Int = try database.sync { db in
            let stmt = try Statement(db: db, sql: "DELETE FROM tasks WHERE updated_at < ?")
            stmt.bind(1, cutoff)
            _ = try stmt.step()
            return Int(sqlite3_changes(db))
        }
        if deleted > 0 {
            try repository.refreshAll()
        }
        return deleted
    }
}
