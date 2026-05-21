import SwiftUI

struct QuickAddField: View {
    @Binding var title: String
    @Binding var details: String
    @Binding var detailsRevealed: Bool
    var titleFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    @FocusState private var detailsFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                TextField("What now?", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused(titleFocused)
                    .onSubmit(onSubmit)
                    .onKeyPress(.tab) {
                        detailsRevealed = true
                        DispatchQueue.main.async { detailsFocused = true }
                        return .handled
                    }
                Button {
                    detailsRevealed.toggle()
                    if detailsRevealed {
                        DispatchQueue.main.async { detailsFocused = true }
                    } else {
                        titleFocused.wrappedValue = true
                    }
                } label: {
                    Image(systemName: detailsRevealed ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle description (Tab)")
            }
            .padding(.horizontal, 12)

            if detailsRevealed {
                TextField("Description (optional)", text: $details, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1...4)
                    .focused($detailsFocused)
                    .onSubmit(onSubmit)
                    .padding(.horizontal, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: detailsRevealed)
        .padding(.bottom, 6)
    }
}
