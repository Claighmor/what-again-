# What Now

A lightweight macOS menubar scratchpad for tasks. Items auto-expire 7 days after their last edit. Pure native Swift + SwiftUI on macOS 14+, with an AppleScript bridge for Raycast integration.

**No Xcode. No SwiftPM. No third-party dependencies.** Just `swiftc` against the system SDK, system SQLite3, and a few shell scripts. Designed to be edited in any editor (Zed-friendly).

## Requirements

- macOS 14 (Sonoma) or later
- Working Swift toolchain — the system one from Command Line Tools is enough, *provided it isn't broken*. See "Troubleshooting" if `swiftc` fails with module redefinition errors.

## Repo layout

```
Sources/WhatNowCore/       Pure model + storage + AppleScript bridge (no UI)
  Models/TaskItem.swift
  Storage/Database.swift           sqlite3 connection wrapper
  Storage/TaskRepository.swift     CRUD + Combine publishers
  Storage/RetentionSweep.swift     7-day purge
  Scripting/ScriptingBridge.swift  NSScriptCommand subclasses + sdef-targetable proxy
App/                       SwiftUI menubar shell
  WhatNowApp.swift                 @main, MenuBarExtra, AppDelegate
  Views/*.swift
  LoginItem.swift                  SMAppService wrapper
  Info.plist
  WhatNow.sdef                     AppleScript surface definition
  WhatNow.entitlements
Tests/                     Standalone XCTest-less test runner
  main.swift
  TestSupport.swift                TestRunner + TestClock
  TaskRepositoryTests.swift
  RetentionSweepTests.swift
build.sh                   swiftc → build/What Now.app, ad-hoc codesign
test.sh                    swiftc → build/run-tests, runs them
```

## Build the app

```sh
./build.sh
open "build/What Now.app"
```

The script:
1. Compiles every `.swift` file in `Sources/WhatNowCore/` and `App/` together.
2. Links system `SQLite3`, `AppKit`, `SwiftUI`, `Combine`, `ServiceManagement`.
3. Assembles the `.app` bundle (`Contents/MacOS/WhatNow`, `Contents/Info.plist`, `Contents/Resources/WhatNow.sdef`).
4. Ad-hoc codesigns with `App/WhatNow.entitlements` applied.

## Run the tests

```sh
./test.sh
```

Tests are plain Swift functions that take a `TestRunner` and call assertion methods on it. No XCTest, no SwiftPM, just an executable that exits nonzero on failure.

## Raycast / AppleScript

```sh
osascript -e 'tell application "What Now" to add task with title "Buy milk"'
osascript -e 'tell application "What Now" to add task with title "Email Jen" description "About the proposal" due date (current date) + 2 * days'
osascript -e 'tell application "What Now" to get title of every task whose completed is false'
osascript -e 'tell application "What Now" to complete task "<uuid>"'
osascript -e 'tell application "What Now" to delete task "<uuid>"'
```

First call triggers a one-time macOS Automation permission prompt for the calling app (Terminal, Raycast, Script Editor, etc.).

A minimal Raycast extension wrapping the above is left as a future task.

## Design decisions (locked)

| Aspect | Choice |
|---|---|
| Min macOS | 14 (Sonoma) |
| Storage | System `SQLite3`, no GRDB or other wrapper |
| Retention | 7 days from last edit, hard-delete |
| Sweep | Lazy filter on read + active sweep on launch + hourly |
| Menubar style | `MenuBarExtra(.window)` — popover |
| Quick add | Always-present TextField at top, auto-focused; Tab reveals description |
| Done state | Checkbox, dimmed, hidden in a "Done" tab |
| Tab switcher | Segmented control with counts |
| Sort | `updated_at DESC` |
| Edit | Inline expand on click |
| Delete | Trash button + swipe + ⌘⌫ |
| Due dates | Quick-select menu, capped at +7 days |
| Notifications | None — visual overdue red highlight only |
| Hotkey | None — Raycast handles global capture |
| Identity | "What Now" / `dev.claymore.whatnow` / Claymore |
| Dock | Hidden (`LSUIElement = YES`) |
| Login | `SMAppService` toggle + first-launch prompt |
| Settings | Footer gear menu: login toggle, Quit, version, Raycast link |
| Popover dismiss | Auto on click-outside |
| AppleScript | `task` class + `add/complete/uncomplete/delete task` verbs + `every task` |
| Sandbox | App-sandbox entitlement on |
| Distribution | Local dev build, ad-hoc signed |

## Troubleshooting

### `swiftc` fails with "redefinition of module 'SwiftBridging'"
Your `/Library/Developer/CommandLineTools` is corrupted. Reinstall:
```sh
sudo rm -rf /Library/Developer/CommandLineTools
sudo xcode-select --install
```

### `Launch at Login` toggle does nothing
`SMAppService.mainApp` only works when the app is in `/Applications/` or signed with a real Developer ID. With ad-hoc local builds living in `build/`, the toggle is a no-op. Move the bundle:
```sh
cp -R "build/What Now.app" /Applications/
```

### AppleScript hangs or asks for permission repeatedly
TCC (privacy) prompts go to the calling app (Terminal/Raycast), not What Now. Open System Settings → Privacy & Security → Automation and verify the calling app has What Now checked.

### Inspect the database
```sh
sqlite3 "$HOME/Library/Containers/dev.claymore.whatnow/Data/Library/Application Support/WhatNow/tasks.db"
sqlite> SELECT id, title, datetime(updated_at, 'unixepoch') FROM tasks;
```
