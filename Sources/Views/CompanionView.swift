import SwiftUI

class CompanionStateHolder: ObservableObject {
    @Published var aggregate: AggregateState = .noSessions
    @Published var sessionCount: Int = 0
    @Published var scale: CGFloat = 0.7  // User-adjustable size
}

enum HangSide {
    case top, left, right, none
}

struct CompanionCharacter: View {
    @ObservedObject var state: CompanionStateHolder
    var onClick: () -> Void

    @State private var bobOffset: CGFloat = 0
    @State private var glowPulse: CGFloat = 0.3
    @State private var flashBright: CGFloat = 0
    @State private var hangSide: HangSide = .top
    @State private var blinkTimer: Bool = false
    @State private var isBlinking: Bool = false

    var body: some View {
        ZStack {
            // The hanging arm/grip
            hangingArm

            // Body
            ZStack {
                // Bright flash ring for needsInput
                if state.aggregate == .needsInput {
                    Circle()
                        .fill(Color.green.opacity(flashBright * 0.6))
                        .frame(width: 70, height: 70)
                        .blur(radius: 14)
                }

                // Glow
                Circle()
                    .fill(stateColor.opacity(glowPulse * 0.3))
                    .frame(width: 50, height: 50)
                    .blur(radius: 10)

                // Main sparkle body
                SparkleBody()
                    .fill(stateColor.opacity(state.aggregate == .needsInput ? (0.7 + flashBright * 0.3) : 0.9))
                    .frame(width: 36, height: 36)
                    .shadow(color: stateColor.opacity(state.aggregate == .needsInput ? flashBright : 0.6), radius: state.aggregate == .needsInput ? 12 : 6)

                // Face
                face

                // Session count badge
                if state.sessionCount > 0 {
                    Text("\(state.sessionCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.black.opacity(0.75)))
                        .offset(x: 20, y: -20)
                }
            }
            .offset(y: bodyOffset)
        }
        .offset(y: bobOffset)
        .scaleEffect(state.scale)
        .contentShape(Rectangle())
        .onTapGesture { onClick() }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                bobOffset = 4
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glowPulse = 1.0
            }
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                flashBright = 1.0
            }
            startBlinkCycle()
        }
        .contextMenu {
            Button("Smaller") { state.scale = max(state.scale - 0.15, 0.4) }
            Button("Bigger") { state.scale = min(state.scale + 0.15, 1.5) }
            Divider()
            Button("Reset Size") { state.scale = 0.7 }
        }
        .frame(width: 120, height: 120)
    }

    private var bodyOffset: CGFloat {
        switch hangSide {
        case .top: return 16
        case .left, .right, .none: return 0
        }
    }

    private var hangingArm: some View {
        Group {
            switch hangSide {
            case .top:
                VStack(spacing: 0) {
                    // Two little gripping arms at the top
                    HStack(spacing: 14) {
                        GripArm(color: stateColor)
                            .rotationEffect(.degrees(-15))
                        GripArm(color: stateColor)
                            .rotationEffect(.degrees(15))
                            .scaleEffect(x: -1, y: 1)
                    }
                    .offset(y: -2)

                    // Thin line connecting to body
                    Rectangle()
                        .fill(stateColor.opacity(0.5))
                        .frame(width: 2, height: 10)
                }
                .offset(y: -28)

            case .left:
                HStack(spacing: 0) {
                    GripArm(color: stateColor)
                        .rotationEffect(.degrees(90))
                    Spacer()
                }
                .offset(x: -20)

            case .right:
                HStack(spacing: 0) {
                    Spacer()
                    GripArm(color: stateColor)
                        .rotationEffect(.degrees(-90))
                        .scaleEffect(x: -1, y: 1)
                }
                .offset(x: 20)

            case .none:
                EmptyView()
            }
        }
    }

    private var face: some View {
        VStack(spacing: 3) {
            // Eyes
            HStack(spacing: 8) {
                EyeView(isBlinking: isBlinking)
                EyeView(isBlinking: isBlinking)
            }

            // Mouth - changes with state
            mouth
        }
        .offset(y: 1)
    }

    private var mouth: some View {
        Group {
            switch state.aggregate {
            case .noSessions:
                // Flat line - neutral/sleeping
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 8, height: 2)
            case .working:
                // Small o - concentrating
                Circle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                    .frame(width: 5, height: 5)
            case .needsInput:
                // Smile - wants attention
                SmilePath()
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                    .frame(width: 10, height: 5)
            }
        }
    }

    private var stateColor: Color {
        switch state.aggregate {
        case .noSessions: return .red
        case .working: return .orange
        case .needsInput: return .green
        }
    }

    private func startBlinkCycle() {
        func scheduleBlink() {
            let delay = Double.random(in: 2.5...5.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.1)) { isBlinking = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.1)) { isBlinking = false }
                    scheduleBlink()
                }
            }
        }
        scheduleBlink()
    }
}

// MARK: - Sub-shapes

struct SparkleBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.42
        let rayCount = 8

        for i in 0..<(rayCount * 2) {
            let angle = (CGFloat(i) / CGFloat(rayCount * 2)) * .pi * 2 - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if i == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

struct GripArm: View {
    let color: Color

    var body: some View {
        ZStack {
            // Arm
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.7))
                .frame(width: 4, height: 14)

            // Little hand/grip at the end
            Circle()
                .fill(color.opacity(0.9))
                .frame(width: 6, height: 6)
                .offset(y: -7)
        }
    }
}

struct EyeView: View {
    let isBlinking: Bool

    var body: some View {
        ZStack {
            if isBlinking {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 7, height: 2)
            } else {
                Ellipse()
                    .fill(Color.white)
                    .frame(width: 7, height: 9)
                Circle()
                    .fill(Color.black)
                    .frame(width: 4, height: 4)
                    .offset(y: 1)
                // Highlight
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 2, height: 2)
                    .offset(x: 1, y: -1)
            }
        }
    }
}

struct SmilePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY + 2)
        )
        return path
    }
}
