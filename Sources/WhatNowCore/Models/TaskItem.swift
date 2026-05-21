import Foundation

public struct TaskItem: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var details: String?
    public var dueAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        details: String? = nil,
        dueAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.dueAt = dueAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    public var isCompleted: Bool { completedAt != nil }
}

public extension TaskItem {
    /// Fraction of the 7-day life that has elapsed since the last edit.
    /// 0 = just edited, 1 = on the verge of expiry.
    func ageFraction(now: Date = Date(), window: TimeInterval = 7 * 24 * 60 * 60) -> Double {
        let elapsed = now.timeIntervalSince(updatedAt)
        return max(0, min(1, elapsed / window))
    }

    var isOverdue: Bool {
        guard let due = dueAt else { return false }
        return due < Date() && completedAt == nil
    }
}
