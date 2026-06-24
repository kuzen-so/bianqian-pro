import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var noteStore = NoteStore()
    private var stickyControllers: [UUID: StickyNoteWindowController] = [:]
    private var lastInteractedNoteId: UUID?
    private var eventMonitor: EventMonitor?
    private var didSetupUI = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement 已在 Info.plist 中设置，无需再调用 setActivationPolicy(.accessory)。
        // 重复设置 accessory 模式会在启动早期触发额外的 Dock 消息，与系统内部状态交互时容易引发崩溃。

        checkApplicationLocation()
        observeScreenChanges()

        // 开机自启时，应用会在 WindowServer / 菜单栏 / Dock 尚未完成初始化、且显示器仍在
        // 反复重配置时就被 launchd 拉起。此刻创建状态栏项与窗口会与系统内部状态竞争，
        // 在随后的 autorelease pool / Dock 回调 drain 时触发过度释放崩溃。
        // 因此把全部 UI 初始化延迟到登录环境基本稳定之后，并保证只执行一次。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.performInitialSetup()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFloatingIslandSettingChanged),
            name: .floatingIslandSettingChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    /// 幂等的 UI 初始化。无论是延迟任务还是首次激活通知先触发，都只会真正执行一次。
    private func performInitialSetup() {
        guard !didSetupUI else { return }
        didSetupUI = true
        setupGlobalShortcut()
        setupStatusBar()
        setupPopover()
        setupEventMonitor()
        setupFloatingIslandIfNeeded()
        restoreStickyNotes()
    }

    @objc private func applicationDidBecomeActive() {
        // 仅在已完成初始化后才注册全局快捷键；初始化本身由延迟任务统一驱动，
        // 避免登录早期的激活通知绕过延迟、过早创建状态栏与窗口。
        guard didSetupUI else { return }
        GlobalShortcutManager.shared.register()
    }

    private func checkApplicationLocation() {
        let bundlePath = Bundle.main.bundlePath
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

    private var isFloatingIslandSetup = false

    private func setupFloatingIslandIfNeeded() {
        let enabled = UserDefaults.standard.bool(forKey: Constants.showFloatingIslandKey)

        guard enabled else {
            FloatingIslandManager.shared.hide()
            return
        }

        guard !isFloatingIslandSetup else {
            FloatingIslandManager.shared.show()
            return
        }

        FloatingIslandManager.shared.setup(
            store: noteStore,
            onOpenNote: { [weak self] note in
                guard let self = self else { return }
                if note.isPinned, let controller = self.stickyControllers[note.id] {
                    controller.window?.makeKey()
                    return
                }
                self.noteStore.updateNote(id: note.id) {
                    if $0.isArchived { $0.isArchived = false }
                    $0.isSticky = true
                }
                if let updated = self.noteStore.notes.first(where: { $0.id == note.id }) {
                    self.openStickyNote(updated)
                }
            },
            onCreateNote: { [weak self] in
                self?.createNewStickyNote()
            },
            onArchiveNote: { [weak self] note in
                self?.noteStore.archive(note)
                self?.stickyControllers[note.id]?.close()
                self?.stickyControllers.removeValue(forKey: note.id)
            }
        )
        isFloatingIslandSetup = true
    }

    @objc private func handleFloatingIslandSettingChanged() {
        setupFloatingIslandIfNeeded()
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func handleScreenChange() {
        FloatingIslandManager.shared.handleScreenChange()
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleLastStickyNoteFromShortcut),
            name: .reopenLastStickyNote,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleCollapseLastStickyNoteFromShortcut),
            name: .toggleCollapseLastStickyNote,
            object: nil
        )
    }

    @objc private func togglePopoverFromShortcut() {
        togglePopover()
    }

    @objc private func createStickyNoteFromShortcut() {
        createNewStickyNote()
    }

    @objc private func toggleLastStickyNoteFromShortcut() {
        toggleLastStickyNote()
    }

    @objc private func toggleCollapseLastStickyNoteFromShortcut() {
        guard let noteId = lastInteractedNoteId else { return }

        if stickyControllers[noteId] == nil {
            guard noteStore.notes.firstIndex(where: { $0.id == noteId }) != nil else { return }
            noteStore.updateNote(id: noteId) {
                if $0.isArchived {
                    $0.isArchived = false
                }
                $0.isSticky = true
            }
            if let updated = noteStore.notes.first(where: { $0.id == noteId }) {
                openStickyNote(updated)
            }
            return
        }

        NotificationCenter.default.post(
            name: .toggleCollapseStickyNote,
            object: nil,
            userInfo: ["noteId": noteId]
        )
    }

    private func toggleLastStickyNote() {
        guard let noteId = lastInteractedNoteId else { return }
        guard noteStore.notes.firstIndex(where: { $0.id == noteId }) != nil else {
            lastInteractedNoteId = nil
            return
        }

        if let controller = stickyControllers[noteId] {
            controller.closeSticky()
            return
        }

        noteStore.updateNote(id: noteId) {
            if $0.isArchived {
                $0.isArchived = false
            }
            $0.isSticky = true
        }
        if let updated = noteStore.notes.first(where: { $0.id == noteId }) {
            openStickyNote(updated)
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            let iconPath = Bundle.main.path(forResource: "statusbar_icon", ofType: "png")
            if let path = iconPath, let image = NSImage(contentsOfFile: path) {
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                button.image = image
            } else {
                button.image = NSImage(
                    systemSymbolName: "square.and.pencil",
                    accessibilityDescription: "便签 Pro"
                )
            }
            button.action = #selector(togglePopover)
            button.target = self
            // 不再调用 button.sendAction(on: [.leftMouseUp, .rightMouseUp])。
            // 在 macOS 26 上，该方法会替换 NSStatusBarButton 的内部事件处理单元，
            // 启动早期的 autorelease pool drain 时容易触发过度释放/野指针崩溃。
            // 右键菜单后续可通过子类化 NSStatusBarButton 或本地事件监听实现。
        }
    }

    private func setupPopover() {
        let newPopover = NSPopover()
        newPopover.behavior = .transient
        newPopover.contentSize = NSSize(width: Constants.popoverSize.width, height: Constants.popoverSize.height)
        newPopover.contentViewController = NSHostingController(
            rootView: PopoverView(store: noteStore, onCreateSticky: { [weak self] note in
                self?.openStickyNote(note)
            })
        )
        popover = newPopover
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
        if popover == nil {
            setupPopover()
        }
        if let button = statusItem?.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor?.start()
        }
    }

    private func closePopover() {
        popover?.performClose(nil)
        eventMonitor?.stop()
    }

    private func openStickyNote(_ note: Note) {
        guard !note.isArchived, stickyControllers[note.id] == nil else { return }

        lastInteractedNoteId = note.id

        let controller = StickyNoteWindowController(
            note: note,
            store: noteStore,
            onClose: { [weak self] in
                guard let self = self else { return }
                self.stickyControllers.removeValue(forKey: note.id)
                self.lastInteractedNoteId = note.id
                self.noteStore.updateNote(id: note.id) { $0.isSticky = false }
            },
            onCreateNew: { [weak self] origin in
                self?.createNewStickyNote(near: origin)
            },
            onArchive: { [weak self] in
                guard let self = self else { return }
                self.stickyControllers[note.id]?.close()
                self.stickyControllers.removeValue(forKey: note.id)
                self.lastInteractedNoteId = note.id
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
            color: systemDefaultNoteColor(),
            isSticky: true,
            isArchived: false,
            tags: []
        )
        if let origin = origin {
            newNote.position = CGPoint(x: origin.x + Constants.stickyCascadeOffset, y: origin.y - Constants.stickyCascadeOffset)
        }
        noteStore.notes.append(newNote)
        noteStore.save()
        openStickyNote(newNote)
    }

    private func restoreStickyNotes() {
        for note in noteStore.notes where note.isSticky {
            openStickyNote(note)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        for controller in stickyControllers.values {
            controller.savePosition()
        }
        noteStore.flushSave()
    }
}
