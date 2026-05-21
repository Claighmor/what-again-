import SwiftUI

struct DueDateMenu: View {
    @Binding var date: Date?
    let onChange: () -> Void

    @State private var showCustom = false

    var body: some View {
        Menu {
            Button("Today") { setOffset(0) }
            Button("Tomorrow") { setOffset(1) }
            Button("This Friday") { setToWeekday(6) }
            Button("+3 days") { setOffset(3) }
            Button("+7 days") { setOffset(7) }
            Divider()
            Button("Custom…") { showCustom = true }
            if date != nil {
                Divider()
                Button("Clear") {
                    date = nil
                    onChange()
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text(label)
                    .font(.system(size: 12))
            }
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .sheet(isPresented: $showCustom) {
            CustomDateSheet(date: $date, isPresented: $showCustom, onChange: onChange)
        }
    }

    private var label: String {
        guard let date else { return "Due date" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func setOffset(_ days: Int) {
        let cal = Calendar.current
        if days == 0 {
            date = cal.startOfDay(for: Date())
        } else {
            let base = cal.startOfDay(for: Date())
            date = cal.date(byAdding: .day, value: days, to: base)
        }
        onChange()
    }

    private func setToWeekday(_ weekday: Int) {
        let cal = Calendar.current
        var components = DateComponents()
        components.weekday = weekday
        let next = cal.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime, direction: .forward)
        if let next, next.timeIntervalSinceNow <= 7 * 86400 {
            date = cal.startOfDay(for: next)
            onChange()
        }
    }
}

private struct CustomDateSheet: View {
    @Binding var date: Date?
    @Binding var isPresented: Bool
    let onChange: () -> Void

    @State private var picked: Date = Calendar.current.startOfDay(for: Date())

    var body: some View {
        VStack {
            DatePicker(
                "Due",
                selection: $picked,
                in: Date()...Date().addingTimeInterval(7 * 86400),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            HStack {
                Button("Cancel") { isPresented = false }
                Spacer()
                Button("Set") {
                    date = picked
                    onChange()
                    isPresented = false
                }
                .keyboardShortcut(.return)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 320)
    }
}
