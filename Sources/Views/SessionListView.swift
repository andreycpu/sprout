import SwiftUI

struct SessionListView: View {
    let sessions: [ClaudeSession]
    let onSelect: (ClaudeSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Claude Sessions")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)

            if sessions.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No active sessions")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ForEach(sessions) { session in
                    SessionRow(session: session)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(session) }
                }
            }
        }
        .padding(.bottom, 8)
    }
}

struct SessionRow: View {
    let session: ClaudeSession

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.projectName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(session.terminalName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(stateLabel)
                        .font(.system(size: 10))
                        .foregroundColor(stateColor)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.001)) // hit area
    }

    private var stateColor: Color {
        switch session.state {
        case .working: return .yellow
        case .needsInput: return .green
        case .idle: return .gray
        }
    }

    private var stateLabel: String {
        switch session.state {
        case .working: return "Working..."
        case .needsInput: return "Needs input"
        case .idle: return "Idle"
        }
    }
}
