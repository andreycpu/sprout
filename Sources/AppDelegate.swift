import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = SessionMonitor()
    private var companionWindow: NSWindow!
    private var companionView: CompanionView!
    private var sessionListWindow: NSPanel?
    private var isDragging = false
    private var dragOffset: NSPoint = .zero

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupCompanionWindow()
        monitor.onUpdate = { [weak self] in
            self?.handleUpdate()
        }
        monitor.start()
    }

    private func setupCompanionWindow() {
        let size = NSSize(width: 64, height: 72)
        guard let screen = NSScreen.main else { return }

        // Position: top center of screen, hanging down from the menu bar
        let x = (screen.frame.width - size.width) / 2 + screen.frame.minX
        let y = screen.frame.maxY - NSStatusBar.system.thickness - size.height

        let win = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: x, y: y), size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.backgroundColor = .clear
        win.isOpaque = false
        win.level = .statusBar
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        win.hasShadow = false
        win.isMovableByWindowBackground = false
        win.ignoresMouseEvents = false

        companionView = CompanionView(frame: NSRect(origin: .zero, size: size))
        companionView.onClick = { [weak self] in self?.companionClicked() }
        companionView.onDrag = { [weak self] delta in self?.handleDrag(delta) }
        win.contentView = companionView

        win.orderFrontRegardless()
        companionWindow = win
    }

    private func handleUpdate() {
        let sessions = monitor.sessions
        let aggregate = aggregateState(sessions)
        companionView.update(state: aggregate, sessionCount: sessions.count)
    }

    private func aggregateState(_ sessions: [ClaudeSession]) -> AggregateState {
        if sessions.isEmpty { return .noSessions }
        if sessions.contains(where: { $0.state == .needsInput }) { return .needsInput }
        return .working
    }

    private func companionClicked() {
        let needInput = monitor.sessions.filter { $0.state == .needsInput }

        if !needInput.isEmpty {
            for session in needInput {
                session.terminalApp?.activate(options: .activateIgnoringOtherApps)
            }
            sessionListWindow?.orderOut(nil)
        } else {
            showSessionList()
        }
    }

    private func handleDrag(_ delta: NSPoint) {
        var frame = companionWindow.frame
        frame.origin.x += delta.x
        frame.origin.y += delta.y
        companionWindow.setFrameOrigin(frame.origin)
    }

    private func showSessionList() {
        if let win = sessionListWindow, win.isVisible {
            win.orderOut(nil)
            return
        }

        let listHeight = min(CGFloat(max(monitor.sessions.count, 1)) * 60 + 40, 340)
        let listWidth: CGFloat = 300

        let companionFrame = companionWindow.frame
        let x = companionFrame.midX - listWidth / 2
        let y = companionFrame.minY - listHeight - 4

        let panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: listWidth, height: listHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = .statusBar
        panel.hasShadow = true

        let hosting = NSHostingView(
            rootView: SessionListView(sessions: monitor.sessions) { [weak self] session in
                session.terminalApp?.activate(options: .activateIgnoringOtherApps)
                self?.sessionListWindow?.orderOut(nil)
            }
            .background(
                VisualEffectBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            )
        )
        panel.contentView = hosting

        panel.orderFrontRegardless()
        sessionListWindow = panel

        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.sessionListWindow?.orderOut(nil)
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
