import Foundation
import AppKit

class SessionMonitor {
    private(set) var sessions: [ClaudeSession] = []
    var onUpdate: (() -> Void)?

    private var pollTimer: DispatchSourceTimer?
    private var dirSource: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "com.sprout.monitor", qos: .utility)
    private let resolver = ProcessResolver()

    private let sessionsDir: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/sessions")
    }()

    private let projectsDir: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }()

    func start() {
        poll()
        startTimer()
        watchSessionsDirectory()
    }

    func stop() {
        pollTimer?.cancel()
        pollTimer = nil
        dirSource?.cancel()
        dirSource = nil
    }

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2.5, repeating: 2.5)
        timer.setEventHandler { [weak self] in self?.poll() }
        timer.resume()
        pollTimer = timer
    }

    private func watchSessionsDirectory() {
        let fd = open(sessionsDir.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: queue
        )
        source.setEventHandler { [weak self] in self?.poll() }
        source.setCancelHandler { close(fd) }
        source.resume()
        dirSource = source
    }

    private func poll() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: sessionsDir.path) else {
            updateSessions([])
            return
        }

        var found: [ClaudeSession] = []

        for file in files where file.hasSuffix(".json") {
            let url = sessionsDir.appendingPathComponent(file)
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pid = json["pid"] as? Int,
                  let sessionId = json["sessionId"] as? String,
                  let cwd = json["cwd"] as? String
            else { continue }

            // Check if process is still alive
            guard kill(pid_t(pid), 0) == 0 else {
                // Clean up stale session file
                try? fm.removeItem(at: url)
                continue
            }

            let startedAt: Date
            if let ts = json["startedAt"] as? Double {
                startedAt = Date(timeIntervalSince1970: ts / 1000)
            } else {
                startedAt = Date()
            }

            let state = detectState(sessionId: sessionId, cwd: cwd, pid: pid_t(pid))
            let terminalApp = resolver.resolve(pid: pid_t(pid))

            let session = ClaudeSession(
                id: sessionId,
                pid: pid_t(pid),
                cwd: cwd,
                startedAt: startedAt,
                state: state,
                terminalApp: terminalApp
            )
            found.append(session)
        }

        updateSessions(found)
    }

    private func detectState(sessionId: String, cwd: String, pid: pid_t) -> SessionActivity {
        // Encode cwd to directory name: /Users/andrey/Projects -> -Users-andrey-Projects
        let encodedCwd = cwd.replacingOccurrences(of: "/", with: "-")
        let jsonlDir = projectsDir.appendingPathComponent(encodedCwd)
        let jsonlFile = jsonlDir.appendingPathComponent("\(sessionId).jsonl")

        guard let lastEntry = readLastJsonlEntry(at: jsonlFile) else {
            return .idle
        }

        // Check the type of the last meaningful entry
        if let type = lastEntry["type"] as? String {
            switch type {
            case "assistant":
                return .needsInput
            case "user":
                return .working
            default:
                break
            }
        }

        // Fallback: check process status
        return checkProcessStatus(pid: pid)
    }

    private func readLastJsonlEntry(at url: URL) -> [String: Any]? {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fh.close() }

        let fileSize = fh.seekToEndOfFile()
        let readSize: UInt64 = min(fileSize, 16384) // Last 16KB
        fh.seek(toFileOffset: fileSize - readSize)

        guard let data = try? fh.readToEnd(),
              let chunk = String(data: data, encoding: .utf8)
        else { return nil }

        let lines = chunk.components(separatedBy: .newlines)
            .reversed()
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Find last line with a meaningful type (user or assistant)
        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = json["type"] as? String,
                  type == "user" || type == "assistant"
            else { continue }
            return json
        }

        return nil
    }

    private func checkProcessStatus(pid: pid_t) -> SessionActivity {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "stat=", "-p", "\(pid)"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let stat = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if stat.contains("S") && stat.contains("+") {
                return .needsInput
            } else if stat.contains("R") {
                return .working
            }
        } catch {}

        return .idle
    }

    private func updateSessions(_ newSessions: [ClaudeSession]) {
        DispatchQueue.main.async { [weak self] in
            self?.sessions = newSessions
            self?.onUpdate?()
        }
    }
}
