import AppKit
import QuartzCore

@MainActor
class ScreenConfetti {
    static func show() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let confettiView = ConfettiView(frame: frame)
        window.contentView = confettiView
        window.makeKeyAndOrderFront(nil)

        confettiView.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.confettiWindowDuration) {
            window.orderOut(nil)
        }
    }
}

class ConfettiView: NSView {
    private var leftEmitter = CAEmitterLayer()
    private var rightEmitter = CAEmitterLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupEmitters()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupEmitters()
    }

    private func setupEmitters() {
        let height = bounds.height

        leftEmitter.emitterPosition = CGPoint(x: 0, y: height / 2)
        leftEmitter.emitterSize = CGSize(width: 10, height: height * 0.6)
        leftEmitter.emitterMode = .outline
        leftEmitter.emitterShape = .line
        leftEmitter.renderMode = .unordered
        leftEmitter.birthRate = 0

        rightEmitter.emitterPosition = CGPoint(x: bounds.width, y: height / 2)
        rightEmitter.emitterSize = CGSize(width: 10, height: height * 0.6)
        rightEmitter.emitterMode = .outline
        rightEmitter.emitterShape = .line
        rightEmitter.renderMode = .unordered
        rightEmitter.birthRate = 0

        let colors: [NSColor] = [
            .systemRed, .systemBlue, .systemGreen, .systemYellow,
            .systemPurple, .systemOrange, .systemPink, .systemCyan, .systemMint
        ]

        leftEmitter.emitterCells = colors.map { makeCell(color: $0, direction: .right) }
        rightEmitter.emitterCells = colors.map { makeCell(color: $0, direction: .left) }

        layer?.addSublayer(leftEmitter)
        layer?.addSublayer(rightEmitter)
    }

    private func makeCell(color: NSColor, direction: Direction) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.birthRate = 200
        cell.lifetime = 4.0
        cell.lifetimeRange = 0.5
        cell.velocity = 600
        cell.velocityRange = 100
        cell.emissionLongitude = direction == .right ? .pi / 2 : -.pi / 2
        cell.emissionRange = .pi / 12
        cell.spin = 8
        cell.spinRange = 10
        cell.scale = 0.3
        cell.scaleRange = 0.1
        cell.scaleSpeed = -0.04
        cell.alphaSpeed = -0.25
        cell.color = color.cgColor
        cell.contents = createParticleImage().cgImage(forProposedRect: nil, context: nil, hints: nil)
        return cell
    }

    private func createParticleImage() -> NSImage {
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        return image
    }

    func start() {
        leftEmitter.birthRate = 1
        rightEmitter.birthRate = 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.leftEmitter.birthRate = 0
            self.rightEmitter.birthRate = 0
        }
    }

    enum Direction {
        case left, right
    }
}
