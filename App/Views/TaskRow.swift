import SwiftUI

struct TaskRow: View {
    let item: TaskItem
    let isExpanded: Bool
    let onTap: () -> Void
    let onToggleComplete: (Bool) -> Void
    let onDelete: () -> Void
    let onCommit: (String, String?, Date?) -> Void

    @State private var titleDraft: String = ""
    @State private var detailsDraft: String = ""
    @State private var dueDraft: Date?
    @FocusState private var editingTitle: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                CheckButton(isOn: item.isCompleted) { onToggleComplete(!item.isCompleted) }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13))
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .lineLimit(isExpanded ? nil : 1)
                    if let due = item.dueAt {
                        DueDatePill(date: due, overdue: item.isOverdue)
                    }
                }
                Spacer(minLength: 0)
                AgeIndicator(fraction: item.ageFraction())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            if isExpanded {
                expandedEditor
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .background(item.isOverdue ? Color.red.opacity(0.08) : Color.clear)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .background {
            if isExpanded {
                Button("", action: onDelete)
                    .keyboardShortcut(.delete, modifiers: .command)
                    .opacity(0)
                    .accessibilityHidden(true)
            }
        }
        .onAppear(perform: seedDrafts)
        .onChange(of: isExpanded) { _, newValue in
            if newValue { seedDrafts() }
        }
        .animation(.easeInOut(duration: 0.15), value: isExpanded)
    }

    private func seedDrafts() {
        titleDraft = item.title
        detailsDraft = item.details ?? ""
        dueDraft = item.dueAt
    }

    @ViewBuilder
    private var expandedEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Title", text: $titleDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($editingTitle)
                .onSubmit(commit)

            TextField("Description", text: $detailsDraft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1...6)
                .onSubmit(commit)

            HStack {
                DueDateMenu(date: $dueDraft, onChange: { commit() })
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete (⌘⌫)")
            }
        }
        .onChange(of: titleDraft) { _, _ in commitDebounced() }
        .onChange(of: detailsDraft) { _, _ in commitDebounced() }
    }

    @State private var commitWorkItem: DispatchWorkItem?
    private func commitDebounced() {
        commitWorkItem?.cancel()
        let item = DispatchWorkItem { commit() }
        commitWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    private func commit() {
        let trimmedTitle = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        onCommit(trimmedTitle, detailsDraft.isEmpty ? nil : detailsDraft, dueDraft)
    }
}

private struct CheckButton: View {
    let isOn: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15))
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "Mark active" : "Mark done")
    }
}

private struct DueDatePill: View {
    let date: Date
    let overdue: Bool
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "calendar")
                .font(.system(size: 9))
            Text(date, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: 10))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(overdue ? Color.red.opacity(0.2) : Color.secondary.opacity(0.15))
        .foregroundStyle(overdue ? Color.red : Color.secondary)
        .clipShape(Capsule())
    }
}

private struct AgeIndicator: View {
    let fraction: Double
    var body: some View {
        Circle()
            .fill(Color.secondary.opacity(0.2 + 0.6 * fraction))
            .frame(width: 5, height: 5)
            .help("\(Int(fraction * 100))% of life used")
    }
}
