import SwiftUI
import AppKit
import Combine

@main
struct WhatNowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("What Now", systemImage: "text.badge.checkmark") {
            PopoverRoot()
                .frame(width: 360)
                .environmentObject(appDelegate.appModel)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppModel: ObservableObject {
    let repository: TaskRepository
    let sweep: RetentionSweep

    @Published var active: [TaskItem] = []
    @Published var done: [TaskItem] = []
    @Published var loadError: String?

    private var cancellables = Set<AnyCancellable>()
    private var sweepTimer: Timer?

    init() throws {
        let url = try Database.defaultURL()
        let db = try Database(url: url)
        let repo = try TaskRepository(database: db)
        self.repository = repo
        self.sweep = RetentionSweep(database: db, repository: repo)
        ScriptingBridge.shared.repository = repo
        startObserving()
        startSweepTimer()
        try? sweep.run()
    }

    private func startObserving() {
        repository.active
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in self?.active = items }
            .store(in: &cancellables)
        repository.done
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in self?.done = items }
            .store(in: &cancellables)
    }

    private func startSweepTimer() {
        sweepTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            try? self?.sweep.run()
        }
    }

    func snapshotForScripting() -> [TaskScriptingObject] {
        let items = (try? repository.fetchAll()) ?? []
        return items.map(TaskScriptingObject.init)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appModel: AppModel

    override init() {
        do {
            self.appModel = try AppModel()
        } catch {
            fatalError("Failed to open database: \(error)")
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LoginItem.promptOnFirstLaunchIfNeeded()
    }

    // AppleScript: expose `tasks` as an application-level element.
    @objc func tasks() -> [TaskScriptingObject] {
        appModel.snapshotForScripting()
    }
}
