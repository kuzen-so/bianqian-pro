import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var noteStore = NoteStore()
    private var stickyControllers: [UUID: StickyNoteWindowController] = [:]
    private var eventMonitor: EventMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        checkApplicationLocation()
        setupStatusBar()
        setupPopover()
        setupEventMonitor()
        restoreStickyNotes()
        setupGlobalShortcut()
    }

    private func checkApplicationLocation() {
        let bundlePath = Bundle.main.bundlePath
        // 只在真正的 .app bundle 中检测（排除 swift run / Xcode 调试）
        guard bundlePath.hasSuffix(".app"),
              !bundlePath.hasPrefix("/Applications/"),
              !bundlePath.contains(".build"),
              !bundlePath.contains("DerivedData")
        else { return }

        let guide = InstallGuideWindowController(
            onMove: { [weak self] in
                self?.moveToApplications()
            },
            onSkip: {}
        )
        guide.showWindow(nil)
    }

    private func moveToApplications() {
        let appName = "便签 Pro.app"
        let sourceURL = Bundle.main.bundleURL
        let destinationURL = URL(fileURLWithPath: "/Applications/\(appName)")

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            let alert = NSAlert()
            alert.messageText = "移动成功"
            alert.informativeText = "便签 Pro 已移动到 /Applications，请从启动台或 Applications 文件夹重新打开。"
            alert.runModal()

            NSApp.terminate(nil)
        } catch {
            let alert = NSAlert()
            alert.messageText = "移动失败"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func setupGlobalShortcut() {
        GlobalShortcutManager.shared.register()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(togglePopoverFromShortcut),
            name: .toggleQuickNotePopover,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(createStickyNoteFromShortcut),
            name: .createQuickNoteSticky,
            object: nil
        )
    }

    @objc private func togglePopoverFromShortcut() {
        togglePopover()
    }

    @objc private func createStickyNoteFromShortcut() {
        createNewStickyNote()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "square.and.pencil",
                accessibilityDescription: "便签 Pro"
            )
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 400, height: 400)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(store: noteStore, onCreateSticky: { [weak self] note in
                self?.openStickyNote(note)
            })
        )
    }

    private func setupEventMonitor() {
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self = self, let popover = self.popover, popover.isShown {
                self.closePopover()
            }
        }
    }

    @objc private func togglePopover() {
        if let popover = popover, popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        setupPopover()
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor?.start()
        }
    }

    private func closePopover() {
        popover?.performClose(nil)
        popover = nil
        eventMonitor?.stop()
    }

    private func openStickyNote(_ note: Note) {
        guard !note.isArchived, stickyControllers[note.id] == nil else { return }

        let controller = StickyNoteWindowController(
            note: note,
            store: noteStore,
            onClose: { [weak self] in
                guard let self = self else { return }
                self.stickyControllers.removeValue(forKey: note.id)
                if var updated = self.noteStore.notes.first(where: { $0.id == note.id }) {
                    updated.isSticky = false
                    self.noteStore.update(updated)
                }
            },
            onCreateNew: { [weak self] origin in
                self?.createNewStickyNote(near: origin)
            },
            onArchive: { [weak self] in
                guard let self = self else { return }
                self.stickyControllers[note.id]?.close()
                self.stickyControllers.removeValue(forKey: note.id)
                self.noteStore.archive(note)
            }
        )

        stickyControllers[note.id] = controller
        controller.showWindow(nil as NSWindow?)
        controller.window?.makeKey()
    }

    private func createNewStickyNote(near origin: CGPoint? = nil) {
        var newNote = Note(
            content: "",
            createdAt: Date(),
            color: systemDefaultColor(),
            isSticky: true,
            isArchived: false,
            tags: []
        )
        if let origin = origin {
            newNote.position = CGPoint(x: origin.x + 30, y: origin.y - 30)
        }
        noteStore.notes.append(newNote)
        noteStore.save()
        openStickyNote(newNote)
    }

    private func systemDefaultColor() -> NoteColor {
        .auto
    }

    private func restoreStickyNotes() {
        for note in noteStore.notes where note.isSticky {
            openStickyNote(note)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        for controller in stickyControllers.values {
            controller.savePosition()
        }
    }
}

class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: ((NSEvent?) -> Void)?

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler!)
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

// MARK: - Install Guide Window

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
