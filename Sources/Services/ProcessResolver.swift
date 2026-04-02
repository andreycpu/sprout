import AppKit

class ProcessResolver {
    private var cache: [pid_t: NSRunningApplication] = [:]

    private let terminalBundleIds: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "net.kovidgoyal.kitty",
        "com.mitchellh.ghostty",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "dev.zed.Zed",
        "com.jetbrains.intellij",
        "com.jetbrains.pycharm",
        "com.jetbrains.WebStorm",
        "com.jetbrains.goland",
        "com.jetbrains.CLion",
        "com.todesktop.230313mzl4w4u92",  // Cursor
        "dev.warp.Warp-Stable",
        "co.zeit.hyper",
        "com.github.atom",
    ]

    func resolve(pid: pid_t) -> NSRunningApplication? {
        if let cached = cache[pid] {
            if !cached.isTerminated { return cached }
            cache.removeValue(forKey: pid)
        }

        // Walk up the PPID chain to find a known terminal app
        var currentPid = pid
        let runningApps = NSWorkspace.shared.runningApplications

        for _ in 0..<10 {
            let ppid = getParentPid(currentPid)
            if ppid <= 1 { break }

            if let app = runningApps.first(where: {
                $0.processIdentifier == ppid && terminalBundleIds.contains($0.bundleIdentifier ?? "")
            }) {
                cache[pid] = app
                return app
            }

            // Also check if the ppid itself matches any running app
            if let app = runningApps.first(where: {
                $0.processIdentifier == ppid && $0.bundleIdentifier != nil
            }) {
                // Check if this is a terminal-like app by bundle ID
                if terminalBundleIds.contains(app.bundleIdentifier ?? "") {
                    cache[pid] = app
                    return app
                }
            }

            currentPid = ppid
        }

        // Fallback: find any running app in the PPID chain
        currentPid = pid
        for _ in 0..<10 {
            let ppid = getParentPid(currentPid)
            if ppid <= 1 { break }

            if let app = runningApps.first(where: {
                $0.processIdentifier == ppid && $0.activationPolicy == .regular
            }) {
                cache[pid] = app
                return app
            }

            currentPid = ppid
        }

        return nil
    }

    private func getParentPid(_ pid: pid_t) -> pid_t {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]

        let result = sysctl(&mib, 4, &info, &size, nil, 0)
        guard result == 0 else { return 0 }

        return info.kp_eproc.e_ppid
    }

    func clearCache() {
        cache.removeAll()
    }
}
