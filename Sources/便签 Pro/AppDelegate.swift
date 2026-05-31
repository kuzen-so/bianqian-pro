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

        let alert = NSAlert()
        alert.messageText = "将 便签 Pro 移动到 Applications 文件夹？"
        alert.informativeText = "移动到 /Applications 后可正常使用开机自启动等功能。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "移动")
        alert.addButton(withTitle: "暂不")

        if alert.runModal() == .alertFirstButtonReturn {
            moveToApplications()
        }
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
            onCreateNew: { [weak self] in
                self?.createNewStickyNote()
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

    private func createNewStickyNote() {
        let newNote = Note(
            content: "",
            createdAt: Date(),
            color: .yellow,
            isSticky: true,
            isArchived: false,
            tags: []
        )
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
