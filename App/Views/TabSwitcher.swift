import SwiftUI

struct TabSwitcher: View {
    @Binding var tab: TaskTab
    let activeCount: Int
    let doneCount: Int

    var body: some View {
        Picker("", selection: $tab) {
            Text("Active \(activeCount)").tag(TaskTab.active)
            Text("Done \(doneCount)").tag(TaskTab.done)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
