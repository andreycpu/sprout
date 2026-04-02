import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = SessionMonitor()
    private var companionWindow: NSPanel!
    private var sessionListWindow: NSPanel?
    private var stateHolder = CompanionStateHolder()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("Sprout: applicationDidFinishLaunching")
        NSApp.setActivationPolicy(.accessory)

        // Delay window creation slightly to ensure app is fully initialized
        DispatchQueue.main.async {
            self.setupCompanionWindow()
            self.monitor.onUpdate = { [weak self] in
                self?.handleUpdate()
            }
            self.monitor.start()
        }
    }

    private func setupCompanionWindow() {
        guard let screen = NSScreen.main else {
            NSLog("Sprout: No main screen!")
            return
        }

        NSLog("Sprout: Screen frame: \(screen.frame), visible: \(screen.visibleFrame)")

        let size = NSSize(width: 120, height: 120)
        let x = screen.visibleFrame.maxX - size.width - 60
        let y = screen.visibleFrame.maxY - size.height - 60

        NSLog("Sprout: Window position: x=\(x), y=\(y)")

        let panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Sprout"
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false

        let hostingView = NSHostingView(
            rootView: CompanionCharacter(state: stateHolder) {
                [weak self] in self?.companionClicked()
            }
        )
        hostingView.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hostingView

        companionWindow = panel
        panel.orderFrontRegardless()

        NSLog("Sprout: Window created, isVisible=\(panel.isVisible), frame=\(panel.frame)")
    }

    private func handleUpdate() {
        let sessions = monitor.sessions
        if sessions.isEmpty {
            stateHolder.aggregate = .noSessions
        } else if sessions.contains(where: { $0.state == .needsInput }) {
            stateHolder.aggregate = .needsInput
        } else {
            stateHolder.aggregate = .working
        }
        stateHolder.sessionCount = sessions.count

        if let win = companionWindow, !win.isVisible {
            NSLog("Sprout: Window disappeared, restoring")
            win.orderFrontRegardless()
        }
    }

    private func companionClicked() {
        NSLog("Sprout: Companion clicked")
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

    private func showSessionList() {
        if let win = sessionListWindow, win.isVisible {
            win.orderOut(nil)
            return
        }

        let listHeight = min(CGFloat(max(monitor.sessions.count, 1)) * 60 + 40, 340)
        let listWidth: CGFloat = 300

        let companionFrame = companionWindow.frame
        let x = companionFrame.midX - listWidth / 2
        let y = companionFrame.minY - listHeight - 8

        let panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: listWidth, height: listHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.level = .floating
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

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
