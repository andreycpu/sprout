import AppKit

struct ClaudeSession: Identifiable {
    let id: String
    let pid: pid_t
    let cwd: String
    let startedAt: Date
    var state: SessionActivity
    var terminalApp: NSRunningApplication?

    var projectName: String {
        (cwd as NSString).lastPathComponent
    }

    var terminalName: String {
        terminalApp?.localizedName ?? "Unknown"
    }
}

enum SessionActivity: Equatable {
    case working
    case needsInput
    case idle
}

enum AggregateState {
    case noSessions
    case working
    case needsInput
}
