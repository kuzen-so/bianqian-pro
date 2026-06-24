import AppKit
import QuartzCore

// MARK: - Snap Result

struct SnapResult {
    var origin: NSPoint
    var guides: [SnapGuideLine]
}

struct SnapGuideLine: Equatable {
    let start: NSPoint
    let end: NSPoint
}

// MARK: - Snap Guide Manager

@MainActor
class SnapGuideManager {
    static let shared = SnapGuideManager()

    private var overlayWindow: NSWindow?
    private var guideView: SnapGuideView?
    private let snapThreshold: CGFloat = 12
    private let spacing: CGFloat = 8

    private init() {}

    // MARK: - Public

    func showGuides(_ guides: [SnapGuideLine]) {
        guard !guides.isEmpty else {
            hide()
            return
        }
        ensureWindow()
        guideView?.guides = guides
        guideView?.needsDisplay = true
        overlayWindow?.orderFrontRegardless()
    }

    func hide() {
        overlayWindow?.orderOut(nil)
    }

    /// 计算拖动时的吸附结果
    func computeSnap(
        windowFrame: NSRect,
        otherFrames: [NSRect],
        screenFrame: NSRect
    ) -> SnapResult {
        let snapEnabled = UserDefaults.standard.object(forKey: Constants.windowSnapEnabledKey) as? Bool ?? true
        guard snapEnabled else {
            return SnapResult(origin: windowFrame.origin, guides: [])
        }

        var snappedOrigin = windowFrame.origin
        var guides: [SnapGuideLine] = []

        let windowLeft = windowFrame.minX
        let windowRight = windowFrame.maxX
        let windowTop = windowFrame.maxY
        let windowBottom = windowFrame.minY

        // --- Screen Edge Snapping ---

        // Screen left edge
        if abs(windowLeft - screenFrame.minX) <= snapThreshold {
            snappedOrigin.x = screenFrame.minX
            guides.append(SnapGuideLine(
                start: NSPoint(x: screenFrame.minX, y: screenFrame.minY),
                end: NSPoint(x: screenFrame.minX, y: screenFrame.maxY)
            ))
        }

        // Screen right edge
        if abs(windowRight - screenFrame.maxX) <= snapThreshold {
            snappedOrigin.x = screenFrame.maxX - windowFrame.width
            guides.append(SnapGuideLine(
                start: NSPoint(x: screenFrame.maxX, y: screenFrame.minY),
                end: NSPoint(x: screenFrame.maxX, y: screenFrame.maxY)
            ))
        }

        // Screen top edge
        if abs(windowTop - screenFrame.maxY) <= snapThreshold {
            snappedOrigin.y = screenFrame.maxY - windowFrame.height
            guides.append(SnapGuideLine(
                start: NSPoint(x: screenFrame.minX, y: screenFrame.maxY),
                end: NSPoint(x: screenFrame.maxX, y: screenFrame.maxY)
            ))
        }

        // Screen bottom edge
        if abs(windowBottom - screenFrame.minY) <= snapThreshold {
            snappedOrigin.y = screenFrame.minY
            guides.append(SnapGuideLine(
                start: NSPoint(x: screenFrame.minX, y: screenFrame.minY),
                end: NSPoint(x: screenFrame.maxX, y: screenFrame.minY)
            ))
        }

        // --- Other Window Snapping ---

        for other in otherFrames {
            let otherLeft = other.minX
            let otherRight = other.maxX
            let otherTop = other.maxY
            let otherBottom = other.minY

            // Align left edges
            if abs(windowLeft - otherLeft) <= snapThreshold {
                snappedOrigin.x = otherLeft
                guides.append(SnapGuideLine(
                    start: NSPoint(x: otherLeft, y: min(windowBottom, otherBottom)),
                    end: NSPoint(x: otherLeft, y: max(windowTop, otherTop))
                ))
            }

            // Align right edges
            if abs(windowRight - otherRight) <= snapThreshold {
                snappedOrigin.x = otherRight - windowFrame.width
                guides.append(SnapGuideLine(
                    start: NSPoint(x: otherRight, y: min(windowBottom, otherBottom)),
                    end: NSPoint(x: otherRight, y: max(windowTop, otherTop))
                ))
            }

            // Align top edges
            if abs(windowTop - otherTop) <= snapThreshold {
                snappedOrigin.y = otherTop - windowFrame.height
                guides.append(SnapGuideLine(
                    start: NSPoint(x: min(windowLeft, otherLeft), y: otherTop),
                    end: NSPoint(x: max(windowRight, otherRight), y: otherTop)
                ))
            }

            // Align bottom edges
            if abs(windowBottom - otherBottom) <= snapThreshold {
                snappedOrigin.y = otherBottom
                guides.append(SnapGuideLine(
                    start: NSPoint(x: min(windowLeft, otherLeft), y: otherBottom),
                    end: NSPoint(x: max(windowRight, otherRight), y: otherBottom)
                ))
            }

            // Snap to right of other (with spacing)
            if abs(windowLeft - (otherRight + spacing)) <= snapThreshold {
                snappedOrigin.x = otherRight + spacing
                guides.append(SnapGuideLine(
                    start: NSPoint(x: otherRight + spacing, y: min(windowBottom, otherBottom)),
                    end: NSPoint(x: otherRight + spacing, y: max(windowTop, otherTop))
                ))
            }

            // Snap to left of other (with spacing)
            if abs(windowRight - (otherLeft - spacing)) <= snapThreshold {
                snappedOrigin.x = otherLeft - spacing - windowFrame.width
                guides.append(SnapGuideLine(
                    start: NSPoint(x: otherLeft - spacing, y: min(windowBottom, otherBottom)),
                    end: NSPoint(x: otherLeft - spacing, y: max(windowTop, otherTop))
                ))
            }

            // Snap above other (with spacing)
            if abs(windowBottom - (otherTop + spacing)) <= snapThreshold {
                snappedOrigin.y = otherTop + spacing
                guides.append(SnapGuideLine(
                    start: NSPoint(x: min(windowLeft, otherLeft), y: otherTop + spacing),
                    end: NSPoint(x: max(windowRight, otherRight), y: otherTop + spacing)
                ))
            }

            // Snap below other (with spacing)
            if abs(windowTop - (otherBottom - spacing)) <= snapThreshold {
                snappedOrigin.y = otherBottom - spacing - windowFrame.height
                guides.append(SnapGuideLine(
                    start: NSPoint(x: min(windowLeft, otherLeft), y: otherBottom - spacing),
                    end: NSPoint(x: max(windowRight, otherRight), y: otherBottom - spacing)
                ))
            }
        }

        return SnapResult(origin: snappedOrigin, guides: guides)
    }

    // MARK: - Private

    private func ensureWindow() {
        guard overlayWindow == nil else { return }

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
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

        let guideView = SnapGuideView(frame: frame)
        window.contentView = guideView

        self.guideView = guideView
        self.overlayWindow = window
    }
}

// MARK: - Snap Guide View

class SnapGuideView: NSView {
    var guides: [SnapGuideLine] = []

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.0)
        context.setLineDash(phase: 0, lengths: [4, 3])

        for guide in guides {
            context.move(to: CGPoint(x: guide.start.x, y: guide.start.y))
            context.addLine(to: CGPoint(x: guide.end.x, y: guide.end.y))
            context.strokePath()
        }
    }
}
