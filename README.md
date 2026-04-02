# Sprout

A macOS menu bar companion that monitors all your active Claude Code CLI sessions at a glance.

Stop switching between terminals to check if Claude needs your input. Sprout watches every session and tells you what's happening with a single colored dot.

## How it works

Sprout reads Claude's session files at `~/.claude/sessions/` and conversation logs to determine each session's state. It never launches Claude or interacts with any API - it's purely a passive monitor.

**Menu bar states:**
- **Red dot** - no Claude sessions running
- **Yellow dot (pulsing)** - Claude is actively working
- **Green dot (flashing)** - one or more sessions need your input

**Click behavior:**
- Sessions need input -> activates those terminal windows
- No input needed -> shows a dropdown with all sessions and their statuses

## Quick Start

```bash
git clone https://github.com/andreycpu/sprout.git
cd sprout
bash setup.sh
open Sprout.xcodeproj
```

Press `Cmd+R` in Xcode to build and run. Sprout will appear as a colored dot in your menu bar.

### Requirements

- macOS 13.0+
- Xcode 15+
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (installed automatically by `setup.sh` via Homebrew)

## Supported terminals

Sprout detects Claude sessions running in:
- Terminal.app
- iTerm2
- Ghostty
- Kitty
- VS Code
- Cursor
- Zed
- JetBrains IDEs (IntelliJ, PyCharm, WebStorm, GoLand, CLion)
- Warp
- Hyper

## Design

- Zero dependencies - pure Swift and AppKit
- Polls every 2.5 seconds with file system watching for immediate new session detection
- Reads only the tail of conversation logs for efficiency
- No network access, no API calls, no data collection

## License

MIT
