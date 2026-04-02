import AppKit

class MenuBarIcon {
    var animationState: AggregateState = .noSessions
    private var flashOn = true
    private var flashTimer: Timer?

    init() {
        startFlashTimer()
    }

    private func startFlashTimer() {
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.flashOn.toggle()
        }
    }

    func render(state: AggregateState, count: Int) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let dotSize: CGFloat = 10
            let dotRect = NSRect(
                x: (rect.width - dotSize) / 2,
                y: (rect.height - dotSize) / 2,
                width: dotSize,
                height: dotSize
            )

            let color: NSColor
            var alpha: CGFloat = 1.0

            switch state {
            case .noSessions:
                color = .systemRed
            case .working:
                color = .systemYellow
                alpha = self.flashOn ? 1.0 : 0.5
            case .needsInput:
                color = .systemGreen
                alpha = self.flashOn ? 1.0 : 0.3
            }

            color.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: dotRect).fill()

            // Draw count badge if > 0
            if count > 0 {
                let countStr = "\(count)" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 7, weight: .bold),
                    .foregroundColor: NSColor.white,
                ]
                let strSize = countStr.size(withAttributes: attrs)
                let strPoint = NSPoint(
                    x: rect.width - strSize.width - 1,
                    y: 1
                )
                countStr.draw(at: strPoint, withAttributes: attrs)
            }

            return true
        }
        image.isTemplate = false
        return image
    }
}
