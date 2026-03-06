# ccMenuBar

A macOS menu bar app that monitors all running Claude Code instances and shows busy/idle status. The solution has two parts:

1. **Claude Code Hooks** (`cc-menubar-plugin/scripts/`) — shell scripts registered as Claude Code hooks that write status to a well-known directory
2. **macOS Menu Bar App** (`ccMenuBar`) — monitors the status directory and shows an animated icon when busy, with a popover listing all sessions

## Features

- Animated menu bar icon — orange pulsing `terminal` icon when any session is busy, static when idle
- Popover with a list of all active sessions showing project name, git branch, status, and last activity time
- Dual monitoring — primary FSEvents-based watcher for plugin status files, with a JSONL mtime polling fallback
- Automatic stale session cleanup after 1 hour of inactivity
- No Dock icon — runs purely in the menu bar

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9+ (ships with Xcode 15+)
- Claude Code CLI

## Installation

### 1. Install the Claude Code Hooks

Install the plugin using the Claude Code CLI:

```sh
claude plugin add "$(PWD)/ccMenuBar/cc-menubar-plugin"
```

This registers the hook scripts from `cc-menubar-plugin/` as a Claude Code plugin. The hooks listen for `SessionStart`, `PreToolUse`, `PostToolUse`, `Notification`, `Stop`, and `SessionEnd` events. Each hook writes a JSON status file to `~/.claude/ccMenuBar/sessions/`.

To verify the plugin is installed:

```sh
claude plugin list
```

To uninstall:

```sh
claude plugin remove cc-menubar-plugin
```

### 2. Build and Run the Menu Bar App

```sh
cd ccMenuBar
swift build
swift run
```

The app appears as a terminal icon in your menu bar. Click it to see the session list.

### 3. (Optional) Launch at Login

To have the app start automatically, add the built binary to your Login Items:

1. Build the release binary: `cd ccMenuBar && swift build -c release`
2. Open **System Settings > General > Login Items**
3. Add `.build/release/ccMenuBar`

## Usage

Once both the plugin and the app are running:

- **Idle** — the menu bar shows a default `terminal` icon
- **Busy** — the icon animates between `terminal` and `terminal.fill` with an orange tint
- **Click the icon** — opens a popover listing all sessions sorted by status (busy first), each showing:
  - Colored status dot (orange = busy, green = idle/active, gray = stale)
  - Project name and git branch
  - Current tool being used (when busy)
  - Relative timestamp of last activity

## How It Works

### Plugin

The plugin shell scripts are invoked by Claude Code hooks. They write/remove JSON files in `~/.claude/ccMenuBar/sessions/`:

```json
{
  "session_id": "abc-123",
  "status": "busy",
  "cwd": "/Users/you/code/myproject",
  "last_event": "PreToolUse",
  "tool_name": "Bash",
  "timestamp": "2026-02-26T12:00:00Z"
}
```

### Menu Bar App

The app watches the sessions directory using FSEvents for near-instant updates. A 3-second polling fallback discovers sessions from `~/.claude/projects/` JSONL file modification times when the plugin is not installed.

## Development

### Project Structure

```
ccMenuBar/
├── install.sh                      # Installs hooks into ~/.claude/settings.json
├── uninstall.sh                    # Removes hooks and installed scripts
├── cc-menubar-plugin/              # Hook scripts (source of truth)
│   ├── hooks/
│   │   └── hooks.json              # Hook event registrations (reference)
│   └── scripts/
│       ├── update-status.sh        # Writes session status JSON
│       └── remove-session.sh       # Removes session file on end
└── ccMenuBar/                      # macOS menu bar app
    ├── Package.swift               # SPM package (macOS 14+, Swift 5.9+)
    └── Sources/
        ├── App/
        │   ├── ccMenuBarApp.swift   # @main entry point
        │   └── AppDelegate.swift    # NSStatusItem, popover, icon animation
        ├── Models/
        │   ├── SessionStatus.swift  # Enum: busy, idle, active, stale
        │   └── ClaudeSession.swift  # Session data model
        ├── Services/
        │   ├── SessionMonitor.swift      # FSEvents + Timer polling
        │   ├── StatusFileReader.swift    # Reads plugin JSON files
        │   ├── SessionFileParser.swift   # JSONL fallback reader
        │   └── ProjectNameResolver.swift # Decodes project dir names
        ├── ViewModels/
        │   └── MenuBarViewModel.swift    # Aggregates session data for views
        └── Views/
            ├── SessionListView.swift     # Popover content
            └── SessionRowView.swift      # Individual session row
```

### Building

```sh
cd ccMenuBar
swift build              # Debug build
swift build -c release   # Release build
```

No Xcode project is needed — the app is built entirely with Swift Package Manager.

### Testing the Hook Scripts

You can test the scripts manually by piping JSON to stdin:

```sh
# Simulate a busy session
echo '{"session_id":"test-1","cwd":"/tmp/myproject","hook_event_name":"PreToolUse","tool_name":"Bash"}' \
  | ~/.claude/ccMenuBar/scripts/update-status.sh

cat ~/.claude/ccMenuBar/sessions/test-1.json

# Simulate session end
echo '{"session_id":"test-1"}' \
  | ~/.claude/ccMenuBar/scripts/remove-session.sh
```

### Architecture

```
FSEvents (watches ~/.claude/ccMenuBar/sessions/)
         │
         v
  SessionMonitor (@Observable)
  ├── sessions: [ClaudeSession]
  └── overallStatus: busy/idle
         │
         v
  MenuBarViewModel (@Observable)
  ├── activeSessions, staleSessions
  └── hasAnyBusySession
         │
         v
  AppDelegate
  ├── NSStatusItem (icon + animation)
  └── NSPopover → SessionListView (SwiftUI)
```

The app uses `@Observable` (Observation framework) for reactive state. `SessionMonitor` owns the data, `MenuBarViewModel` transforms it for the views, and `AppDelegate` manages the menu bar icon and popover.
