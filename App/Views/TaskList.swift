import SwiftUI

struct TaskList: View {
    let items: [TaskItem]
    @Binding var expandedID: UUID?
    let isDoneTab: Bool

    @EnvironmentObject private var model: AppModel

    var body: some View {
        if items.isEmpty {
            EmptyTaskState(isDoneTab: isDoneTab)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else {
            List {
                ForEach(items) { item in
                    TaskRow(
                        item: item,
                        isExpanded: expandedID == item.id,
                        onTap: {
                            expandedID = (expandedID == item.id) ? nil : item.id
                        },
                        onToggleComplete: { complete in
                            try? model.repository.setCompleted(id: item.id, completed: complete)
                        },
                        onDelete: {
                            try? model.repository.delete(id: item.id)
                            if expandedID == item.id { expandedID = nil }
                        },
                        onCommit: { title, details, due in
                            try? model.repository.update(
                                id: item.id,
                                title: title,
                                details: .some(details),
                                dueAt: .some(due)
                            )
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(maxHeight: 360)
        }
    }
}

struct EmptyTaskState: View {
    let isDoneTab: Bool
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: isDoneTab ? "checkmark.circle" : "tray")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text(isDoneTab ? "Nothing finished yet." : "Nothing on your plate.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
