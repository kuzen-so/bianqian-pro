import SwiftUI
import AppKit
import QuartzCore

extension Notification.Name {
    static let stickyNoteDoubleClicked = Notification.Name("stickyNoteDoubleClicked")
    static let stickyNoteEscPressed = Notification.Name("stickyNoteEscPressed")
}

@MainActor
class StickyNoteWindowController: NSWindowController {
    private var note: Note
    private var store: NoteStore
    private var onClose: () -> Void
    private var onCreateNew: (CGPoint) -> Void
    private var onArchive: () -> Void
    private var expandedSize: CGSize?

    init(note: Note, store: NoteStore, onClose: @escaping () -> Void, onCreateNew: @escaping (CGPoint) -> Void = { _ in }, onArchive: @escaping () -> Void = {}) {
        self.note = note
        self.store = store
        self.onClose = onClose
        self.onCreateNew = onCreateNew
        self.onArchive = onArchive

        let window = StickyNoteWindow(
            contentRect: NSRect(origin: .zero, size: Constants.stickyDefaultSize),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.minSize = Constants.stickyMinSize

        super.init(window: window)

        setupContentView()

        let resolvedOrigin = Self.resolveWindowPosition(for: note, stickyCount: store.notes.filter { $0.isSticky }.count)
        window.setFrameOrigin(resolvedOrigin)

        if let size = note.size {
            window.setContentSize(NSSize(width: size.width, height: size.height))
        }
    }

    /// 根据 note 的 position + screenID 解析窗口应在的全局坐标
    private static func resolveWindowPosition(for note: Note, stickyCount: Int) -> NSPoint {
        // 没有位置信息，使用默认级联位置
        guard let position = note.position else {
            let offset = CGFloat(stickyCount) * Constants.stickyCascadeOffset
            return NSPoint(x: Constants.defaultStickyOrigin.x + offset, y: Constants.defaultStickyOrigin.y - offset)
        }

        // 没有 screenID（兼容旧数据），直接信任 position
        guard let screenID = note.screenID else {
            return NSPoint(x: position.x, y: position.y)
        }

        // 尝试找到对应的屏幕
        guard let targetScreen = NSScreen.screens.first(where: { screenID == screenIdentifier($0) }) else {
            // 屏幕不存在了，fallback 到主屏幕中心附近
            if let mainScreen = NSScreen.main ?? NSScreen.screens.first {
                let offset = CGFloat(stickyCount) * Constants.stickyCascadeOffset
                return NSPoint(
                    x: mainScreen.frame.midX - Constants.stickyDefaultSize.width / 2 + offset,
                    y: mainScreen.frame.midY - Constants.stickyDefaultSize.height / 2 - offset
                )
            }
            return NSPoint(x: position.x, y: position.y)
        }

        // 检查 position 是否仍在目标屏幕可见范围内（容错 20px）
        let padding: CGFloat = 20
        let safeFrame = NSRect(
            x: targetScreen.frame.origin.x + padding,
            y: targetScreen.frame.origin.y + padding,
            width: targetScreen.frame.size.width - padding * 2,
            height: targetScreen.frame.size.height - padding * 2
        )

        if safeFrame.contains(NSPoint(x: position.x, y: position.y)) {
            return NSPoint(x: position.x, y: position.y)
        }

        // 位置不在该屏幕内，放到该屏幕中心附近
        let offset = CGFloat(stickyCount) * Constants.stickyCascadeOffset
        return NSPoint(
            x: targetScreen.frame.midX - Constants.stickyDefaultSize.width / 2 + offset,
            y: targetScreen.frame.midY - Constants.stickyDefaultSize.height / 2 - offset
        )
    }

    private static func screenIdentifier(_ screen: NSScreen) -> String {
        String(format: "%.0f,%.0f,%.0f,%.0f",
               screen.frame.origin.x,
               screen.frame.origin.y,
               screen.frame.size.width,
               screen.frame.size.height)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContentView() {
        guard let window = self.window as? StickyNoteWindow else { return }

        // 容器视图统一负责圆角裁剪
        let containerView = NSView(frame: window.contentView?.bounds ?? .zero)
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = Constants.UI.cornerRadius
        containerView.layer?.masksToBounds = true
        containerView.autoresizingMask = [.width, .height]

        // 底层毛玻璃模糊
        let visualEffectView = NSVisualEffectView(frame: containerView.bounds)
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]

        // SwiftUI 内容层
        let hostingView = NSHostingView(rootView: StickyNoteView(
            note: note,
            store: store,
            onClose: { [weak self] in
                self?.closeSticky()
            },
            onCreateNew: { [weak self] in
                guard let self = self, let window = self.window else { return }
                self.onCreateNew(window.frame.origin)
            },
            onArchive: { [weak self] in
                self?.onArchive()
            },
            onToggleCollapse: { [weak self] collapsed in
                self?.toggleCollapse(collapsed)
            }
        ))
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]

        containerView.addSubview(visualEffectView)
        containerView.addSubview(hostingView)
        window.contentView = containerView
        window.noteId = note.id
    }

    func closeSticky() {
        savePosition()
        onClose()
        close()
    }

    func savePosition() {
        guard let window = self.window else { return }
        guard var updated = store.notes.first(where: { $0.id == note.id }) else { return }
        updated.position = CGPoint(x: window.frame.origin.x, y: window.frame.origin.y)
        updated.size = CGSize(width: window.frame.size.width, height: window.frame.size.height)
        updated.screenID = screenIdentifier(for: window)
        store.update(updated)

        if window.frame.size.height > Constants.stickyCollapsedHeight {
            expandedSize = window.frame.size
        }
    }

    /// 根据窗口中心点所在屏幕返回屏幕标识
    private func screenIdentifier(for window: NSWindow) -> String? {
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) else { return nil }
        return Self.screenIdentifier(screen)
    }

    private func toggleCollapse(_ collapsed: Bool) {
        guard let window = self.window else { return }
        let currentFrame = window.frame

        if collapsed {
            if expandedSize == nil {
                expandedSize = currentFrame.size
            }
            let collapsedHeight = Constants.stickyCollapsedHeight
            let newOriginY = currentFrame.origin.y + (currentFrame.size.height - collapsedHeight)
            let newFrame = NSRect(
                x: currentFrame.origin.x,
                y: newOriginY,
                width: currentFrame.size.width,
                height: collapsedHeight
            )
            animateWindow(to: newFrame, minSize: NSSize(width: Constants.stickyMinSize.width, height: collapsedHeight))
        } else {
            let height = expandedSize?.height ?? Constants.stickyDefaultSize.height
            let newOriginY = currentFrame.origin.y + (currentFrame.size.height - height)
            let newFrame = NSRect(
                x: currentFrame.origin.x,
                y: newOriginY,
                width: currentFrame.size.width,
                height: height
            )
            animateWindow(to: newFrame, minSize: Constants.stickyMinSize)
        }
    }

    private func animateWindow(to newFrame: NSRect, minSize: NSSize) {
        guard let window = self.window else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Constants.animationCollapseDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }, completionHandler: {
            MainActor.assumeIsolated {
                window.minSize = minSize
            }
        })
    }
}

class StickyNoteWindow: NSWindow {
    var noteId: UUID?
    private var initialDragLocation: NSPoint?
    private let titleBarHeight: CGFloat = Constants.titleBarHeight

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown && event.keyCode == 53 {
            NotificationCenter.default.post(
                name: .stickyNoteEscPressed,
                object: nil,
                userInfo: ["noteId": noteId as Any]
            )
            return
        }

        switch event.type {
        case .leftMouseDown:
            if event.clickCount == 2, isInTitleBar(event) {
                NotificationCenter.default.post(
                    name: .stickyNoteDoubleClicked,
                    object: nil,
                    userInfo: ["noteId": noteId as Any]
                )
                break
            }
            if isInTitleBar(event) {
                initialDragLocation = NSEvent.mouseLocation
            }
        case .leftMouseDragged:
            guard let initialDragLocation = initialDragLocation else { break }
            let currentLocation = NSEvent.mouseLocation
            let deltaX = currentLocation.x - initialDragLocation.x
            let deltaY = currentLocation.y - initialDragLocation.y

            var newOrigin = frame.origin
            newOrigin.x += deltaX
            newOrigin.y += deltaY

            // 吸附计算
            let otherFrames = NSApplication.shared.windows
                .compactMap { $0 as? StickyNoteWindow }
                .filter { $0.noteId != self.noteId }
                .map { $0.frame }
            let screenFrame = self.screen?.frame ?? NSScreen.main?.frame ?? .zero

            let snapResult = SnapGuideManager.shared.computeSnap(
                windowFrame: NSRect(origin: newOrigin, size: frame.size),
                otherFrames: otherFrames,
                screenFrame: screenFrame
            )

            setFrameOrigin(snapResult.origin)
            SnapGuideManager.shared.showGuides(snapResult.guides)

            self.initialDragLocation = currentLocation
        case .leftMouseUp:
            guard initialDragLocation != nil else { break }
            initialDragLocation = nil
            SnapGuideManager.shared.hide()
            if let controller = windowController as? StickyNoteWindowController {
                controller.savePosition()
            }
        default:
            break
        }

        super.sendEvent(event)
    }

    private func isInTitleBar(_ event: NSEvent) -> Bool {
        let location = event.locationInWindow
        let height = contentView?.bounds.height ?? frame.height
        let effectiveHeight = min(height, titleBarHeight)
        return location.y > height - effectiveHeight
    }
}
