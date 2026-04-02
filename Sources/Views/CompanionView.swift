import SwiftUI

class CompanionStateHolder: ObservableObject {
    @Published var aggregate: AggregateState = .noSessions
    @Published var sessionCount: Int = 0
    @Published var scale: CGFloat = 1.0
}

struct CompanionCharacter: View {
    @ObservedObject var state: CompanionStateHolder
    var onClick: () -> Void

    @State private var bobOffset: CGFloat = 0
    @State private var flashBright: CGFloat = 0
    @State private var isBlinking = false
    @State private var legFrame = 0

    var body: some View {
        ZStack {
            // Glow underneath when needs input
            if state.aggregate == .needsInput {
                Ellipse()
                    .fill(Color.green.opacity(flashBright * 0.4))
                    .frame(width: 60, height: 20)
                    .blur(radius: 8)
                    .offset(y: 28)
            }

            // The pixel pet
            PixelPet(
                color: stateColor,
                isBlinking: isBlinking,
                legFrame: legFrame,
                flashBright: state.aggregate == .needsInput ? flashBright : 0
            )

            // Session count badge
            if state.sessionCount > 0 {
                Text("\(state.sessionCount)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(Color.black.opacity(0.8)))
                    .offset(x: 28, y: -22)
            }
        }
        .offset(y: bobOffset)
        .scaleEffect(state.scale)
        .contentShape(Rectangle())
        .onTapGesture { onClick() }
        .contextMenu {
            Button("Smaller") { withAnimation { state.scale = max(state.scale - 0.2, 0.5) } }
            Button("Bigger") { withAnimation { state.scale = min(state.scale + 0.2, 2.0) } }
            Divider()
            Button("Reset Size") { withAnimation { state.scale = 1.0 } }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                bobOffset = 3
            }
            withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) {
                flashBright = 1.0
            }
            startBlinkCycle()
            startLegAnimation()
        }
        .frame(width: 120, height: 120)
    }

    private var stateColor: Color {
        switch state.aggregate {
        case .noSessions: return Color(red: 0.85, green: 0.35, blue: 0.3)
        case .working: return Color(red: 0.9, green: 0.65, blue: 0.3)
        case .needsInput: return Color(red: 0.3, green: 0.85, blue: 0.4)
        }
    }

    private func startBlinkCycle() {
        func scheduleBlink() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2.0...4.5)) {
                isBlinking = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    isBlinking = false
                    scheduleBlink()
                }
            }
        }
        scheduleBlink()
    }

    private func startLegAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            legFrame = (legFrame + 1) % 2
        }
    }
}

// MARK: - Pixel Art Pet

struct PixelPet: View {
    let color: Color
    let isBlinking: Bool
    let legFrame: Int
    let flashBright: CGFloat

    private let px: CGFloat = 5  // pixel size

    var body: some View {
        Canvas { context, size in
            let ox = size.width / 2 - px * 5  // center the 10px-wide body
            let oy = size.height / 2 - px * 4

            // Draw body pixels
            for (row, cols) in bodyPixels.enumerated() {
                for col in cols {
                    let rect = CGRect(x: ox + CGFloat(col) * px, y: oy + CGFloat(row) * px, width: px, height: px)
                    context.fill(Path(rect), with: .color(bodyColor(row: row)))
                }
            }

            // Eyes
            if isBlinking {
                // Blink - just thin lines
                let eyeY = oy + 2 * px
                context.fill(Path(CGRect(x: ox + 3 * px, y: eyeY + px * 0.3, width: px, height: px * 0.4)), with: .color(.black))
                context.fill(Path(CGRect(x: ox + 6 * px, y: eyeY + px * 0.3, width: px, height: px * 0.4)), with: .color(.black))
            } else {
                // Open eyes
                let eyeY = oy + 2 * px
                context.fill(Path(CGRect(x: ox + 3 * px, y: eyeY, width: px, height: px)), with: .color(.black))
                context.fill(Path(CGRect(x: ox + 6 * px, y: eyeY, width: px, height: px)), with: .color(.black))
                // Eye highlights
                context.fill(Path(CGRect(x: ox + 3 * px + 1, y: eyeY + 1, width: px * 0.4, height: px * 0.4)), with: .color(.white.opacity(0.7)))
                context.fill(Path(CGRect(x: ox + 6 * px + 1, y: eyeY + 1, width: px * 0.4, height: px * 0.4)), with: .color(.white.opacity(0.7)))
            }

            // Mouth
            let mouthY = oy + 4 * px
            context.fill(Path(CGRect(x: ox + 4 * px, y: mouthY, width: px * 0.8, height: px * 0.5)), with: .color(.black.opacity(0.6)))

            // Legs (animated)
            drawLegs(context: &context, ox: ox, oy: oy)

            // Tail
            let tailY = oy + 5 * px
            context.fill(Path(CGRect(x: ox + 9 * px, y: tailY, width: px, height: px)), with: .color(darkerColor))
            context.fill(Path(CGRect(x: ox + 10 * px, y: tailY + px, width: px, height: px)), with: .color(darkerColor))
            context.fill(Path(CGRect(x: ox + 11 * px, y: tailY + px, width: px, height: px * 0.6)), with: .color(darkerColor))
        }
        .frame(width: 90, height: 70)
        .shadow(color: flashBright > 0.5 ? color.opacity(0.8) : .clear, radius: 10)
    }

    // Body shape - each row is a list of filled column indices
    private var bodyPixels: [[Int]] {
        [
            //       row 0: top of head
            [2, 3, 4, 5, 6, 7],
            //       row 1: head wider
            [1, 2, 3, 4, 5, 6, 7, 8],
            //       row 2: eyes row
            [1, 2, 3, 4, 5, 6, 7, 8],
            //       row 3: face
            [1, 2, 3, 4, 5, 6, 7, 8],
            //       row 4: mouth/chin
            [2, 3, 4, 5, 6, 7, 8],
            //       row 5: body
            [2, 3, 4, 5, 6, 7, 8],
            //       row 6: lower body
            [2, 3, 4, 5, 6, 7],
        ]
    }

    private func bodyColor(row: Int) -> Color {
        if row <= 1 {
            return color // head top - main color
        } else if row <= 4 {
            return color.opacity(0.85) // face area - slightly different
        } else {
            return color.opacity(0.75) // lower body - darker
        }
    }

    private var darkerColor: Color {
        color.opacity(0.5)
    }

    private func drawLegs(context: inout GraphicsContext, ox: CGFloat, oy: CGFloat) {
        let legY = oy + 7 * px
        let legColor = color.opacity(0.7)

        if legFrame == 0 {
            // Frame 0: legs spread
            context.fill(Path(CGRect(x: ox + 2 * px, y: legY, width: px, height: px)), with: .color(legColor))
            context.fill(Path(CGRect(x: ox + 4 * px, y: legY, width: px, height: px)), with: .color(legColor))
            context.fill(Path(CGRect(x: ox + 6 * px, y: legY, width: px, height: px)), with: .color(legColor))
        } else {
            // Frame 1: legs together
            context.fill(Path(CGRect(x: ox + 3 * px, y: legY, width: px, height: px)), with: .color(legColor))
            context.fill(Path(CGRect(x: ox + 5 * px, y: legY, width: px, height: px)), with: .color(legColor))
            context.fill(Path(CGRect(x: ox + 7 * px, y: legY, width: px, height: px)), with: .color(legColor))
        }
    }
}
