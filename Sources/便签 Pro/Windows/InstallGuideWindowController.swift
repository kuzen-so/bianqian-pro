import AppKit

class InstallGuideWindowController: NSWindowController {
    private var onMove: (() -> Void)?
    private var onSkip: (() -> Void)?

    init(onMove: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.onMove = onMove
        self.onSkip = onSkip

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "安装 便签 Pro"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        setupContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContent() {
        guard let window = self.window else { return }
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 300))

        let appIcon = NSImageView(frame: NSRect(x: 100, y: 160, width: 72, height: 72))
        appIcon.image = NSApp.applicationIconImage
        container.addSubview(appIcon)

        let arrow = NSTextField(labelWithString: "→")
        arrow.frame = NSRect(x: 204, y: 176, width: 32, height: 40)
        arrow.font = NSFont.systemFont(ofSize: 28)
        arrow.alignment = .center
        container.addSubview(arrow)

        let appsIcon = NSImageView(frame: NSRect(x: 268, y: 160, width: 72, height: 72))
        appsIcon.image = NSWorkspace.shared.icon(forFile: "/Applications")
        container.addSubview(appsIcon)

        let info = NSTextField(wrappingLabelWithString: "将 便签 Pro 移动到 Applications 文件夹，以获得最佳体验。")
        info.frame = NSRect(x: 40, y: 100, width: 360, height: 40)
        info.alignment = .center
        info.font = NSFont.systemFont(ofSize: 13)
        container.addSubview(info)

        let moveButton = NSButton(frame: NSRect(x: 120, y: 50, width: 200, height: 32))
        moveButton.title = "移动到 Applications"
        moveButton.bezelStyle = .rounded
        moveButton.target = self
        moveButton.action = #selector(moveClicked)
        container.addSubview(moveButton)

        let laterButton = NSButton(frame: NSRect(x: 120, y: 18, width: 200, height: 20))
        laterButton.title = "暂不移动，直接运行"
        laterButton.bezelStyle = .recessed
        laterButton.font = NSFont.systemFont(ofSize: 11)
        laterButton.target = self
        laterButton.action = #selector(skipClicked)
        container.addSubview(laterButton)

        window.contentView = container
    }

    @objc private func moveClicked() {
        onMove?()
    }

    @objc private func skipClicked() {
        onSkip?()
        close()
    }
}
