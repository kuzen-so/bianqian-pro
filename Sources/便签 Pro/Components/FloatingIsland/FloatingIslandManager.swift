import SwiftUI
import AppKit
import Combine

@MainActor
class FloatingIslandManager: ObservableObject {
    static let shared = FloatingIslandManager()

    private var floatingWindow: NSWindow?
    private var hoverCheckTimer: DispatchSourceTimer?
    private var cancellables = Set<AnyCancellable>()

    /// 灵动岛当前是否应当可见。仅当为 true 且窗口已创建时，才响应屏幕参数变化重建窗口。
    private var isVisible = false
    /// 屏幕参数变化防抖任务。
    private var screenChangeWorkItem: DispatchWorkItem?

    @Published var isExpanded = false

    private var noteStore: NoteStore?
    private var onOpenNote: ((Note) -> Void)?
    private var onCreateNote: (() -> Void)?
    private var onArchiveNote: ((Note) -> Void)?

    // MARK: - Hover Check Optimizations

    /// 上次检测到的鼠标位置，用于跳过未移动时的重复计算
    private var lastMouseLocation: NSPoint?
    /// 上次检测时窗口的 frame，用于判断窗口是否移动
    private var lastWindowFrame: NSRect?
    /// 是否正在执行展开/收起动画，动画期间跳过检测
    private var isTransitioning = false

    private init() {}

    func setup(
        store: NoteStore,
        onOpenNote: @escaping (Note) -> Void,
        onCreateNote: @escaping () -> Void,
        onArchiveNote: @escaping (Note) -> Void
    ) {
        self.noteStore = store
        self.onOpenNote = onOpenNote
        self.onCreateNote = onCreateNote
        self.onArchiveNote = onArchiveNote

        isVisible = true
        createFloatingWindow()
        startHoverCheck()
        observeAppState()
    }

    deinit {
        hoverCheckTimer?.cancel()
    }

    // MARK: - App State Observation

    private func observeAppState() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppActivation),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDeactivation),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }

    @objc private func handleAppActivation() {
        startHoverCheck()
    }

    @objc private func handleAppDeactivation() {
        pauseHoverCheck()
        // 应用切换到后台时自动收起，避免展开状态遮挡其他应用
        if isExpanded {
            collapse()
        }
    }

    // MARK: - Hover Detection

    private func startHoverCheck() {
        pauseHoverCheck()

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.performHoverCheck()
            }
        }
        timer.resume()
        hoverCheckTimer = timer
    }

    private func pauseHoverCheck() {
        hoverCheckTimer?.cancel()
        hoverCheckTimer = nil
    }

    private func performHoverCheck() {
        guard !isTransitioning, let window = floatingWindow else { return }

        let mouseLoc = NSEvent.mouseLocation
        let windowFrame = window.frame

        // 优化1: 鼠标未移动且窗口未动，直接跳过
        if let lastMouse = lastMouseLocation,
           let lastFrame = lastWindowFrame,
           mouseLoc == lastMouse,
           windowFrame == lastFrame {
            return
        }
        lastMouseLocation = mouseLoc
        lastWindowFrame = windowFrame

        // 检测范围比窗口稍大，便于悬停触发
        let checkFrame = windowFrame.insetBy(dx: -20, dy: -10)
        let inWindow = checkFrame.contains(mouseLoc)

        if inWindow && !isExpanded {
            expand()
        } else if !inWindow && isExpanded {
            collapse()
        }
    }

    // MARK: - Expand / Collapse

    private func expand() {
        guard !isExpanded, !isTransitioning else { return }
        isTransitioning = true
        isExpanded = true
        updateWindowState()
        // 动画期间及完成后重置标志
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Island.animationDuration + 0.05) {
            self.isTransitioning = false
        }
    }

    private func collapse() {
        guard isExpanded, !isTransitioning else { return }
        isTransitioning = true
        isExpanded = false
        updateWindowState()
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Island.animationDuration + 0.05) {
            self.isTransitioning = false
        }
    }

    func hide() {
        isVisible = false
        floatingWindow?.orderOut(nil)
    }

    func show() {
        isVisible = true
        floatingWindow?.orderFrontRegardless()
    }

    // MARK: - Window Management

    private func createFloatingWindow() {
        guard let screen = targetScreen() else { return }
        let frame = collapsedFrame(for: screen)

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = false
        window.ignoresMouseEvents = true

        updateContentView(for: window)

        floatingWindow = window
        window.orderFrontRegardless()
    }

    private func updateContentView(for window: NSWindow) {
        guard let store = noteStore else { return }

        let contentView = FloatingIslandView(
            store: store,
            manager: self,
            onOpenNote: { [weak self] note in
                self?.onOpenNote?(note)
            },
            onCreateNote: { [weak self] in
                self?.onCreateNote?()
            },
            onArchiveNote: { [weak self] note in
                self?.onArchiveNote?(note)
            }
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.masksToBounds = true
        window.contentView = hostingView
    }

    private func updateWindowState() {
        guard let window = floatingWindow else { return }
        guard let screen = targetScreen() else { return }

        let newFrame = isExpanded ? expandedFrame(for: screen) : collapsedFrame(for: screen)

        // 展开时接收鼠标事件
        window.ignoresMouseEvents = !isExpanded

        // 使用 AppKit 标准窗口动画，比 NSAnimationContext 更自然
        window.setFrame(newFrame, display: true, animate: true)
    }

    // MARK: - Frame Calculation

    private func collapsedFrame(for screen: NSScreen) -> NSRect {
        let width = Constants.Island.collapsedWidth
        let height = Constants.Island.collapsedHeight
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func expandedFrame(for screen: NSScreen) -> NSRect {
        let width = Constants.Island.expandedWidth
        let height = Constants.Island.expandedHeight
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY - height
        return NSRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - Screen

    private func targetScreen() -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first
    }

    // MARK: - Screen Changes

    func handleScreenChange() {
        // 未启用时不应重建窗口，避免登录早期显示器重配置风暴。
        guard isVisible, floatingWindow != nil else {
            floatingWindow?.orderOut(nil)
            floatingWindow = nil
            return
        }

        // 防抖：显示器参数变化可能连续触发多次，0.3s 后合并处理。
        screenChangeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.rebuildWindow()
        }
        screenChangeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    private func rebuildWindow() {
        let wasExpanded = isExpanded
        floatingWindow?.close()
        floatingWindow = nil
        isExpanded = false
        createFloatingWindow()
        if wasExpanded {
            expand()
        }
    }
}
