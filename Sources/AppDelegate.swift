import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let monitor = SessionMonitor()
    private let iconRenderer = MenuBarIcon()
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        monitor.onUpdate = { [weak self] in
            self?.handleUpdate()
        }
        monitor.start()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = iconRenderer.render(state: .noSessions, count: 0)
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }

    private func handleUpdate() {
        let sessions = monitor.sessions
        let aggregate = aggregateState(sessions)
        iconRenderer.animationState = aggregate

        if let button = statusItem.button {
            button.image = iconRenderer.render(state: aggregate, count: sessions.count)
            if sessions.count > 0 {
                button.title = " \(sessions.count)"
            } else {
                button.title = ""
            }
        }
    }

    private func aggregateState(_ sessions: [ClaudeSession]) -> AggregateState {
        if sessions.isEmpty { return .noSessions }
        if sessions.contains(where: { $0.state == .needsInput }) { return .needsInput }
        return .working
    }

    @objc func statusItemClicked() {
        let needInput = monitor.sessions.filter { $0.state == .needsInput }

        if !needInput.isEmpty {
            for session in needInput {
                session.terminalApp?.activate(options: .activateIgnoringOtherApps)
            }
            popover?.close()
        } else {
            showSessionList()
        }
    }

    private func showSessionList() {
        if let popover = popover, popover.isShown {
            popover.close()
            return
        }

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 320, height: min(CGFloat(max(monitor.sessions.count, 1)) * 60 + 40, 340))
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(
            rootView: SessionListView(sessions: monitor.sessions) { [weak self] session in
                session.terminalApp?.activate(options: .activateIgnoringOtherApps)
                self?.popover?.close()
            }
        )
        popover = pop

        if let button = statusItem.button {
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
