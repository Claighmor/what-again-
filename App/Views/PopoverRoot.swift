import SwiftUI

enum TaskTab: String, CaseIterable, Identifiable {
    case active, done
    var id: String { rawValue }
}

struct PopoverRoot: View {
    @EnvironmentObject private var model: AppModel
    @State private var tab: TaskTab = .active
    @State private var expandedID: UUID?
    @State private var draftTitle: String = ""
    @State private var draftDetails: String = ""
    @State private var detailsRevealed = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let err = model.loadError {
                ErrorBanner(text: err) { /* future: retry */ }
            }
            QuickAddField(
                title: $draftTitle,
                details: $draftDetails,
                detailsRevealed: $detailsRevealed,
                titleFocused: $titleFocused,
                onSubmit: submit
            )
            Divider()
            TabSwitcher(tab: $tab, activeCount: model.active.count, doneCount: model.done.count)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            TaskList(
                items: tab == .active ? model.active : model.done,
                expandedID: $expandedID,
                isDoneTab: tab == .done
            )
            Divider()
            FooterMenu()
        }
        .padding(.top, 8)
        .onAppear { titleFocused = true }
    }

    private func submit() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let details = draftDetails.isEmpty ? nil : draftDetails
        do {
            try model.repository.create(title: title, details: details)
            draftTitle = ""
            draftDetails = ""
            detailsRevealed = false
            titleFocused = true
        } catch {
            // surfaced via the inline banner pattern in a future iteration
            NSLog("create failed: \(error)")
        }
    }
}

struct ErrorBanner: View {
    let text: String
    let retry: () -> Void
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
            Text(text).font(.caption)
            Spacer()
            Button("Retry", action: retry).buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color.red.opacity(0.15))
    }
}
