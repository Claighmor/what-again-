import Foundation
import AppKit

/// Process-wide bridge between the AppleScript runtime and the storage layer.
/// The app delegate sets `shared.repository` on launch; NSScriptCommand subclasses
/// and the application's `tasks` element accessor read it back.
public final class ScriptingBridge: @unchecked Sendable {
    public static let shared = ScriptingBridge()

    public var repository: TaskRepository?

    private init() {}
}

/// AppleScript-visible task proxy. The `cocoa class` in WhatNow.sdef targets this
/// class. Each instance is uniquely identified by `id` (UUID string) inside the
/// application's `tasks` element collection.
@objc(WNTaskScriptingObject)
public final class TaskScriptingObject: NSObject {
    public let item: TaskItem
    public init(item: TaskItem) { self.item = item }

    @objc public var id: String { item.id.uuidString }
    @objc public var title: String {
        get { item.title }
        set { update { try $0.update(id: item.id, title: newValue) } }
    }
    @objc public var taskDescription: String? {
        get { item.details }
        set { update { try $0.update(id: item.id, details: .some(newValue)) } }
    }
    @objc public var dueAt: Date? {
        get { item.dueAt }
        set { update { try $0.update(id: item.id, dueAt: .some(newValue)) } }
    }
    @objc public var createdAt: Date { item.createdAt }
    @objc public var updatedAt: Date { item.updatedAt }
    @objc public var completed: Bool {
        get { item.isCompleted }
        set { update { try $0.setCompleted(id: item.id, completed: newValue) } }
    }
    @objc public var completedAt: Date? { item.completedAt }

    public override var objectSpecifier: NSScriptObjectSpecifier? {
        guard let appClass = NSScriptClassDescription(for: NSApplication.self) else { return nil }
        return NSUniqueIDSpecifier(
            containerClassDescription: appClass,
            containerSpecifier: nil,
            key: "tasks",
            uniqueID: id
        )
    }

    private func update(_ work: (TaskRepository) throws -> Void) {
        guard let repo = ScriptingBridge.shared.repository else { return }
        do { try work(repo) } catch {
            NSLog("WhatNow scripting update failed: \(error)")
        }
    }
}

// MARK: - NSScriptCommand subclasses

/// `add task with title "x" description "y" due date <date>` → returns the new task.
@objc(WNAddTaskCommand)
public final class AddTaskCommand: NSScriptCommand {
    public override func performDefaultImplementation() -> Any? {
        guard let repo = ScriptingBridge.shared.repository else {
            scriptErrorNumber = NSInternalScriptError
            scriptErrorString = "What Now is not ready."
            return nil
        }
        let args = evaluatedArguments ?? [:]
        guard let title = (directParameter as? String) ?? (args["title"] as? String), !title.isEmpty else {
            scriptErrorNumber = errOSAParameterMismatch
            scriptErrorString = "add task requires a title."
            return nil
        }
        let details = args["details"] as? String
        let dueAt = args["dueAt"] as? Date
        do {
            let item = try repo.create(title: title, details: details, dueAt: dueAt)
            return TaskScriptingObject(item: item)
        } catch TaskRepositoryError.dueDateBeyondRetentionWindow {
            scriptErrorNumber = errOSAGeneralError
            scriptErrorString = "Due date must be within 7 days."
            return nil
        } catch {
            scriptErrorNumber = errOSAGeneralError
            scriptErrorString = "\(error)"
            return nil
        }
    }
}

@objc(WNCompleteTaskCommand)
public final class CompleteTaskCommand: NSScriptCommand {
    public override func performDefaultImplementation() -> Any? {
        performSetCompleted(true)
    }

    func performSetCompleted(_ value: Bool) -> Any? {
        guard let repo = ScriptingBridge.shared.repository else {
            scriptErrorNumber = NSInternalScriptError
            return nil
        }
        guard let id = resolveTaskID() else { return nil }
        do {
            let item = try repo.setCompleted(id: id, completed: value)
            return TaskScriptingObject(item: item)
        } catch {
            scriptErrorNumber = errOSAGeneralError
            scriptErrorString = "\(error)"
            return nil
        }
    }

    func resolveTaskID() -> UUID? {
        if let direct = directParameter as? TaskScriptingObject { return direct.item.id }
        if let idString = (evaluatedArguments?["id"] as? String) ?? (directParameter as? String),
           let id = UUID(uuidString: idString) {
            return id
        }
        scriptErrorNumber = errOSAParameterMismatch
        scriptErrorString = "Expected a task or its id."
        return nil
    }
}

@objc(WNUncompleteTaskCommand)
public final class UncompleteTaskCommand: CompleteTaskCommand {
    public override func performDefaultImplementation() -> Any? {
        performSetCompleted(false)
    }
}

@objc(WNDeleteTaskCommand)
public final class DeleteTaskCommand: NSScriptCommand {
    public override func performDefaultImplementation() -> Any? {
        guard let repo = ScriptingBridge.shared.repository else {
            scriptErrorNumber = NSInternalScriptError
            return nil
        }
        guard let id = resolveTaskID() else { return nil }
        do {
            try repo.delete(id: id)
            return nil
        } catch {
            scriptErrorNumber = errOSAGeneralError
            scriptErrorString = "\(error)"
            return nil
        }
    }

    private func resolveTaskID() -> UUID? {
        if let direct = directParameter as? TaskScriptingObject { return direct.item.id }
        if let idString = (evaluatedArguments?["id"] as? String) ?? (directParameter as? String),
           let id = UUID(uuidString: idString) {
            return id
        }
        scriptErrorNumber = errOSAParameterMismatch
        scriptErrorString = "Expected a task or its id."
        return nil
    }
}
