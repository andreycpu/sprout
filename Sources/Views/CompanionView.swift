import SwiftUI

class CompanionStateHolder: ObservableObject {
    @Published var aggregate: AggregateState = .noSessions
    @Published var sessionCount: Int = 0
}

struct CompanionCharacter: View {
    @ObservedObject var state: CompanionStateHolder
    var onClick: () -> Void

    @State private var bobOffset: CGFloat = 0
    @State private var glowPulse: CGFloat = 0.3

    var body: some View {
        ZStack {
            // Soft circular background so it's always visible
            Circle()
                .fill(stateColor.opacity(0.15))
                .frame(width: 100, height: 100)

            // Glow
            Circle()
                .fill(stateColor.opacity(glowPulse * 0.5))
                .frame(width: 80, height: 80)
                .blur(radius: 12)

            // Main body - sparkle shape
            SparkleShape()
                .fill(stateColor)
                .frame(width: 55, height: 55)
                .shadow(color: stateColor.opacity(0.8), radius: 10)

            // Eyes
            HStack(spacing: 10) {
                Eye()
                Eye()
            }
            .offset(y: 2)

            // Session count badge
            if state.sessionCount > 0 {
                Text("\(state.sessionCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.black.opacity(0.75)))
                    .offset(x: 34, y: -34)
            }
        }
        .offset(y: bobOffset)
        .contentShape(Circle().size(width: 120, height: 120))
        .onTapGesture { onClick() }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                bobOffset = 5
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glowPulse = 1.0
            }
        }
        .frame(width: 120, height: 120)
    }

    private var stateColor: Color {
        switch state.aggregate {
        case .noSessions: return .red
        case .working: return .orange
        case .needsInput: return .green
        }
    }
}

struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.38
        let rayCount = 8

        for i in 0..<(rayCount * 2) {
            let angle = (CGFloat(i) / CGFloat(rayCount * 2)) * .pi * 2 - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct Eye: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.white)
                .frame(width: 10, height: 12)
            Circle()
                .fill(Color.black)
                .frame(width: 5, height: 5)
                .offset(y: 1)
        }
    }
}
