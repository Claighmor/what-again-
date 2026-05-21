import Foundation
import ServiceManagement
import AppKit

enum LoginItem {
    private static let firstLaunchKey = "WhatNow.didPromptForLaunchAtLogin"

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("LoginItem toggle failed: \(error)")
        }
    }

    static func promptOnFirstLaunchIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: firstLaunchKey) else { return }
        defaults.set(true, forKey: firstLaunchKey)

        let alert = NSAlert()
        alert.messageText = "Launch What Now at login?"
        alert.informativeText = "What Now lives in your menu bar. Launching at login keeps it ready when you need to jot something quickly."
        alert.addButton(withTitle: "Enable")
        alert.addButton(withTitle: "Not now")
        if alert.runModal() == .alertFirstButtonReturn {
            setEnabled(true)
        }
    }
}
