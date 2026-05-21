import SwiftUI
import AppKit

struct FooterMenu: View {
    @State private var launchAtLogin = LoginItem.isEnabled
    private let version: String = {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }()

    var body: some View {
        HStack(spacing: 0) {
            Text("v\(version)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
            Menu {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        LoginItem.setEnabled(newValue)
                        launchAtLogin = LoginItem.isEnabled
                    }
                ))
                Divider()
                Link("Raycast extension…", destination: URL(string: "https://raycast.com/")!)
                Divider()
                Button("Quit What Now") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
