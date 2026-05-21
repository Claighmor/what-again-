import Foundation
import Combine

/// Hard ceiling on how long a task may live since its last edit.
public let retentionWindow: TimeInterval = 7 * 24 * 60 * 60

public enum TaskRepositoryError: Error, Equatable {
    case titleEmpty
    case dueDateBeyondRetentionWindow
    case notFound(UUID)
}

public final class TaskRepository: @unchecked Sendable {
    private let database: Database
    private let clock: @Sendable () -> Date

    private let activeSubject = CurrentValueSubject<[TaskItem], Never>([])
    private let doneSubject = CurrentValueSubject<[TaskItem], Never>([])

    public init(database: Database, clock: @escaping @Sendable () -> Date = { Date() }) throws {
        self.database = database
        self.clock = clock
        try refreshAll()
    }

    // MARK: - Validation

    private func validateDueDate(_ date: Date?) throws {
        guard let date else { return }
        let limit = clock().addingTimeInterval(retentionWindow)
        if date > limit {
            throw TaskRepositoryError.dueDateBeyondRetentionWindow
        }
    }

    // MARK: - Writes

    @discardableResult
    public func create(title: String, details: String? = nil, dueAt: Date? = nil) throws -> TaskItem {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TaskRepositoryError.titleEmpty }
        try validateDueDate(dueAt)

        let now = clock()
        let item = TaskItem(
            title: trimmed,
            details: (details?.isEmpty == true) ? nil : details,
            dueAt: dueAt,
            createdAt: now,
            updatedAt: now
        )
        try database.sync { db in
            let stmt = try Statement(db: db, sql: """
                INSERT INTO tasks (id, title, details, due_at, created_at, updated_at, completed_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """)
            stmt.bind(1, item.id.uuidString)
            stmt.bind(2, item.title)
            stmt.bind(3, item.details)
            stmt.bind(4, item.dueAt)
            stmt.bind(5, item.createdAt)
            stmt.bind(6, item.updatedAt)
            stmt.bind(7, item.completedAt)
            _ = try stmt.step()
        }
        try refreshAll()
        return item
    }

    @discardableResult
    public func update(
        id: UUID,
        title: String? = nil,
        details: String?? = nil,
        dueAt: Date?? = nil
    ) throws -> TaskItem {
        try validateDueDate(dueAt ?? nil)

        guard var item = try fetch(id: id) else {
            throw TaskRepositoryError.notFound(id)
        }
        if let title {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw TaskRepositoryError.titleEmpty }
            item.title = trimmed
        }
        if let details {
            item.details = (details?.isEmpty == true) ? nil : details
        }
        if let dueAt {
            item.dueAt = dueAt
        }
        item.updatedAt = clock()

        try database.sync { db in
            let stmt = try Statement(db: db, sql: """
                UPDATE tasks SET title = ?, details = ?, due_at = ?, updated_at = ? WHERE id = ?
            """)
            stmt.bind(1, item.title)
            stmt.bind(2, item.details)
            stmt.bind(3, item.dueAt)
            stmt.bind(4, item.updatedAt)
            stmt.bind(5, item.id.uuidString)
            _ = try stmt.step()
        }
        try refreshAll()
        return item
    }

    @discardableResult
    public func setCompleted(id: UUID, completed: Bool) throws -> TaskItem {
        guard var item = try fetch(id: id) else {
            throw TaskRepositoryError.notFound(id)
        }
        let now = clock()
        item.completedAt = completed ? now : nil
        item.updatedAt = now
        try database.sync { db in
            let stmt = try Statement(db: db, sql: """
                UPDATE tasks SET completed_at = ?, updated_at = ? WHERE id = ?
            """)
            stmt.bind(1, item.completedAt)
            stmt.bind(2, item.updatedAt)
            stmt.bind(3, item.id.uuidString)
            _ = try stmt.step()
        }
        try refreshAll()
        return item
    }

    public func delete(id: UUID) throws {
        try database.sync { db in
            let stmt = try Statement(db: db, sql: "DELETE FROM tasks WHERE id = ?")
            stmt.bind(1, id.uuidString)
            _ = try stmt.step()
        }
        try refreshAll()
    }

    // MARK: - Reads

    private func freshCutoff() -> Date {
        clock().addingTimeInterval(-retentionWindow)
    }

    public func fetchAll() throws -> [TaskItem] {
        try selectMany(sql: """
            SELECT id, title, details, due_at, created_at, updated_at, completed_at
            FROM tasks
            WHERE updated_at >= ?
            ORDER BY updated_at DESC
            """,
            bindCutoff: true
        )
    }

    public func fetchActive() throws -> [TaskItem] {
        try selectMany(sql: """
            SELECT id, title, details, due_at, created_at, updated_at, completed_at
            FROM tasks
            WHERE updated_at >= ? AND completed_at IS NULL
            ORDER BY updated_at DESC
            """,
            bindCutoff: true
        )
    }

    public func fetchDone() throws -> [TaskItem] {
        try selectMany(sql: """
            SELECT id, title, details, due_at, created_at, updated_at, completed_at
            FROM tasks
            WHERE updated_at >= ? AND completed_at IS NOT NULL
            ORDER BY updated_at DESC
            """,
            bindCutoff: true
        )
    }

    public func fetch(id: UUID) throws -> TaskItem? {
        try database.sync { db -> TaskItem? in
            let stmt = try Statement(db: db, sql: """
                SELECT id, title, details, due_at, created_at, updated_at, completed_at
                FROM tasks WHERE id = ?
            """)
            stmt.bind(1, id.uuidString)
            if try stmt.step() {
                return readRow(stmt)
            }
            return nil
        }
    }

    private func selectMany(sql: String, bindCutoff: Bool) throws -> [TaskItem] {
        try database.sync { db -> [TaskItem] in
            let stmt = try Statement(db: db, sql: sql)
            if bindCutoff { stmt.bind(1, freshCutoff()) }
            var out: [TaskItem] = []
            while try stmt.step() {
                if let item = readRow(stmt) { out.append(item) }
            }
            return out
        }
    }

    private func readRow(_ stmt: Statement) -> TaskItem? {
        guard let idString = stmt.text(0), let id = UUID(uuidString: idString) else { return nil }
        guard let title = stmt.text(1) else { return nil }
        return TaskItem(
            id: id,
            title: title,
            details: stmt.text(2),
            dueAt: stmt.date(3),
            createdAt: stmt.date(4) ?? Date(),
            updatedAt: stmt.date(5) ?? Date(),
            completedAt: stmt.date(6)
        )
    }

    // MARK: - Observation

    public var active: AnyPublisher<[TaskItem], Never> {
        activeSubject.eraseToAnyPublisher()
    }

    public var done: AnyPublisher<[TaskItem], Never> {
        doneSubject.eraseToAnyPublisher()
    }

    func refreshAll() throws {
        activeSubject.send(try fetchActive())
        doneSubject.send(try fetchDone())
    }
}
