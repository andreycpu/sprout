import AppKit

class CompanionView: NSView {
    var onClick: (() -> Void)?
    var onDrag: ((NSPoint) -> Void)?

    private var currentState: AggregateState = .noSessions
    private var sessionCount: Int = 0
    private var animationPhase: CGFloat = 0
    private var animationTimer: Timer?
    private var lastDragLocation: NSPoint = .zero
    private var bobOffset: CGFloat = 0
    private var bobPhase: CGFloat = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        startAnimations()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        startAnimations()
    }

    func update(state: AggregateState, sessionCount: Int) {
        self.currentState = state
        self.sessionCount = sessionCount
        needsDisplay = true
    }

    private func startAnimations() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.animationPhase += 0.05
            self.bobPhase += 0.03
            self.bobOffset = sin(self.bobPhase) * 2
            self.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)

        let centerX = bounds.midX
        let centerY = bounds.midY + bobOffset

        // Draw the stem hanging from the top
        let stemColor = stateColor(alpha: 0.6)
        ctx.setStrokeColor(stemColor)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: centerX, y: bounds.maxY))
        ctx.addLine(to: CGPoint(x: centerX, y: centerY + 20))
        ctx.strokePath()

        // Draw glow behind the logo
        let glowAlpha = pulseAlpha() * 0.3
        let glowColor = stateColor(alpha: glowAlpha)
        ctx.setShadow(offset: .zero, blur: 12, color: glowColor)

        // Draw the Claude sparkle logo
        drawClaude(ctx: ctx, center: CGPoint(x: centerX, y: centerY), size: 20)

        // Reset shadow for badge
        ctx.setShadow(offset: .zero, blur: 0)

        // Draw session count badge
        if sessionCount > 0 {
            drawBadge(ctx: ctx, count: sessionCount, position: CGPoint(x: centerX + 16, y: centerY + 12))
        }
    }

    private func drawClaude(ctx: CGContext, center: CGPoint, size: CGFloat) {
        // Claude's sparkle/asterisk logo - 8 tapered rays from center
        let color = stateColor(alpha: pulseAlpha())
        ctx.setFillColor(color)

        let rayCount = 8
        let innerRadius: CGFloat = size * 0.18
        let outerRadius: CGFloat = size
        let rayWidth: CGFloat = size * 0.22

        for i in 0..<rayCount {
            let angle = (CGFloat(i) / CGFloat(rayCount)) * .pi * 2 - .pi / 2
            let cos_a = cos(angle)
            let sin_a = sin(angle)
            let cos_perp = cos(angle + .pi / 2)
            let sin_perp = sin(angle + .pi / 2)

            let path = CGMutablePath()
            // Inner point left
            path.move(to: CGPoint(
                x: center.x + cos_perp * rayWidth * 0.5,
                y: center.y + sin_perp * rayWidth * 0.5
            ))
            // Outer tip
            path.addLine(to: CGPoint(
                x: center.x + cos_a * outerRadius,
                y: center.y + sin_a * outerRadius
            ))
            // Inner point right
            path.addLine(to: CGPoint(
                x: center.x - cos_perp * rayWidth * 0.5,
                y: center.y - sin_perp * rayWidth * 0.5
            ))
            path.closeSubpath()
            ctx.addPath(path)
            ctx.fillPath()
        }

        // Center circle
        let centerRect = CGRect(
            x: center.x - innerRadius * 1.5,
            y: center.y - innerRadius * 1.5,
            width: innerRadius * 3,
            height: innerRadius * 3
        )
        ctx.fillEllipse(in: centerRect)
    }

    private func drawBadge(ctx: CGContext, count: Int, position: CGPoint) {
        let badgeSize: CGFloat = 14
        let badgeRect = CGRect(
            x: position.x - badgeSize / 2,
            y: position.y - badgeSize / 2,
            width: badgeSize,
            height: badgeSize
        )

        ctx.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
        ctx.fillEllipse(in: badgeRect)

        let str = "\(count)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let strSize = str.size(withAttributes: attrs)
        let strPoint = NSPoint(
            x: position.x - strSize.width / 2,
            y: position.y - strSize.height / 2
        )
        str.draw(at: strPoint, withAttributes: attrs)
    }

    private func stateColor(alpha: CGFloat) -> CGColor {
        switch currentState {
        case .noSessions:
            return NSColor.systemRed.withAlphaComponent(alpha).cgColor
        case .working:
            return NSColor.systemOrange.withAlphaComponent(alpha).cgColor
        case .needsInput:
            return NSColor.systemGreen.withAlphaComponent(alpha).cgColor
        }
    }

    private func pulseAlpha() -> CGFloat {
        switch currentState {
        case .noSessions:
            return 0.7
        case .working:
            // Slow gentle pulse
            return 0.6 + sin(animationPhase * 2) * 0.4
        case .needsInput:
            // Faster attention-grabbing flash
            return 0.5 + sin(animationPhase * 4) * 0.5
        }
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        lastDragLocation = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        let current = NSEvent.mouseLocation
        let delta = NSPoint(
            x: current.x - lastDragLocation.x,
            y: current.y - lastDragLocation.y
        )
        lastDragLocation = current
        onDrag?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        if abs(event.deltaX) < 2 && abs(event.deltaY) < 2 {
            onClick?()
        }
    }
}
