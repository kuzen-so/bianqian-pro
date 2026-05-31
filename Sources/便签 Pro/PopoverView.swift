import SwiftUI
import ServiceManagement
import ApplicationServices

struct PopoverView: View {
    @ObservedObject var store: NoteStore
    @Environment(\.colorScheme) var colorScheme
    @State private var newNoteText = ""
    @State private var selectedColor: NoteColor = .gray
    @State private var showColorPicker = false
    @State private var showArchived = false
    @State private var newTagText = ""
    @State private var showTagAlert = false
    @State private var selectedNoteForTag: Note?
    @State private var showSettings = false
    var onCreateSticky: (Note) -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerView
                tabSwitcher
                noteList
                inputArea
            }
            .frame(width: 400, height: 400)
            .background(.regularMaterial)

            if showSettings {
                SettingsView(store: store, onClose: { showSettings = false })
                    .frame(width: 400, height: 400)
                    .background(.regularMaterial)
                    .transition(.move(edge: .trailing))
            }
        }
        .onAppear {
            selectedColor = colorScheme == .dark ? .dark : .gray
        }
        .alert("添加标签", isPresented: $showTagAlert) {
            TextField("标签名称", text: $newTagText)
            Button("取消", role: .cancel) { newTagText = "" }
            Button("添加") {
                if let note = selectedNoteForTag {
                    store.addTag(to: note, tag: newTagText)
                }
                newTagText = ""
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text("便签 Pro")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()

            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showSettings = true } }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            Button("活跃") {
                showArchived = false
            }
            .font(.system(size: 12, weight: showArchived ? .regular : .semibold))
            .foregroundStyle(showArchived ? .secondary : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(showArchived ? Color.clear : Color.gray.opacity(0.15))
            .cornerRadius(6)

            Button("完成") {
                showArchived = true
            }
            .font(.system(size: 12, weight: showArchived ? .semibold : .regular))
            .foregroundStyle(showArchived ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(showArchived ? Color.gray.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var inputArea: some View {
        ReturnToSubmitTextEditor(text: $newNoteText, onSubmit: addNote)
            .frame(height: 80)
            .padding(8)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    private var noteList: some View {
        NoScrollbarScrollView {
            LazyVStack(spacing: 4) {
                let filtered = store.notes
                    .filter { $0.isArchived == showArchived }
                    .sorted(by: {
                        if $0.isPinned != $1.isPinned {
                            return $0.isPinned && !$1.isPinned
                        }
                        return $0.createdAt < $1.createdAt
                    })

                ForEach(filtered) { note in
                    if showArchived {
                        ArchivedNoteRow(
                            note: note,
                            store: store,
                            onRestore: { restoreNote(note) },
                            onAddTag: { showTagDialog(for: note) }
                        )
                        .padding(.horizontal, 12)
                    } else {
                        NoteRow(
                            note: note,
                            store: store,
                            onPinToDesktop: { pinNote(note) },
                            onAddTag: { showTagDialog(for: note) }
                        )
                        .padding(.horizontal, 12)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.vertical, 4)
        }
        .background(Color.clear)
    }

    private func showTagDialog(for note: Note) {
        selectedNoteForTag = note
        showTagAlert = true
    }

    private func addNote() {
        let text = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.add(text, color: selectedColor)
        newNoteText = ""
    }

    private func createStickyNote() {
        let text = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let note = Note(
            content: text,
            createdAt: Date(),
            color: selectedColor,
            isSticky: true,
            isArchived: false,
            tags: []
        )
        store.notes.append(note)
        store.save()
        onCreateSticky(note)
        newNoteText = ""
    }

    private func pinNote(_ note: Note) {
        var updated = note
        updated.isSticky = true
        store.update(updated)
        onCreateSticky(updated)
    }

    private func restoreNote(_ note: Note) {
        store.unarchive(note)
        var updated = note
        updated.isArchived = false
        updated.isSticky = true
        store.update(updated)
        onCreateSticky(updated)
    }
}

struct NoteRow: View {
    let note: Note
    @ObservedObject var store: NoteStore
    var onPinToDesktop: () -> Void
    var onAddTag: () -> Void
    @State private var isHovering = false

    private var dateText: String {
        note.createdAt.formatted(date: .numeric, time: .shortened)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }

                    Text(note.content)
                        .font(.system(size: 13))
                        .lineLimit(3)
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 4) {
                    Text(dateText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if !note.tags.isEmpty {
                        HStack(spacing: 2) {
                            ForEach(note.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(3)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(note.color.swiftUIColor.opacity(note.isPinned ? 0.5 : 0.4))
        .cornerRadius(8)
        .onTapGesture(count: 2) {
            onPinToDesktop()
        }
        .contextMenu {
            Button(note.isPinned ? "取消置顶" : "置顶") {
                if note.isPinned {
                    store.unpin(note)
                } else {
                    store.pin(note)
                }
            }
            Button("显示到桌面") {
                onPinToDesktop()
            }
            Menu("颜色") {
                ForEach(NoteColor.allCases, id: \.self) { color in
                    Button(action: {
                        var updated = note
                        updated.color = color
                        store.update(updated)
                    }) {
                        Image(systemName: "circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(color.swiftUIColor)
                            .imageScale(.large)
                    }
                }
            }
            Button("添加标签") {
                onAddTag()
            }
            Button("同步到 Obsidian") {
                ObsidianSyncManager.shared.syncSingleNote(note)
            }
            Divider()
            Button("删除", role: .destructive) {
                store.delete(note)
            }
        }
    }
}

struct ArchivedNoteRow: View {
    let note: Note
    @ObservedObject var store: NoteStore
    var onRestore: () -> Void
    var onAddTag: () -> Void

    private var dateText: String {
        note.createdAt.formatted(date: .numeric, time: .shortened)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.content)
                    .font(.system(size: 13))
                    .lineLimit(3)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text(dateText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if !note.tags.isEmpty {
                        HStack(spacing: 2) {
                            ForEach(note.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(3)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(note.color.swiftUIColor.opacity(0.25))
        .cornerRadius(8)
        .onTapGesture(count: 2) {
            onRestore()
        }
        .contextMenu {
            Button("恢复") {
                onRestore()
            }
            Menu("颜色") {
                ForEach(NoteColor.allCases, id: \.self) { color in
                    Button(action: {
                        var updated = note
                        updated.color = color
                        store.update(updated)
                    }) {
                        Image(systemName: "circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(color.swiftUIColor)
                            .imageScale(.large)
                    }
                }
            }
            Button("添加标签") {
                onAddTag()
            }
            Button("同步到 Obsidian") {
                ObsidianSyncManager.shared.syncSingleNote(note)
            }
            Divider()
            Button("删除", role: .destructive) {
                store.delete(note)
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var store: NoteStore
    var onClose: () -> Void
    @State private var launchAtLogin = false
    @State private var isRecordingAction: ShortcutAction? = nil
    @State private var hasAccessibilityPermission = false
    @State private var obsidianVaultPath: String = ObsidianSyncManager.shared.vaultPath ?? ""

    var body: some View {
        VStack(spacing: 0) {
            header
            settingsContent
        }
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
            checkAccessibilityPermission()
            // 重新注册全局快捷键（权限可能已变更）
            GlobalShortcutManager.shared.register()
        }
        .task {
            // 每秒检查一次权限状态，授权后自动刷新 UI
            while !Task.isCancelled {
                checkAccessibilityPermission()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    private var header: some View {
        HStack {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { onClose() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("返回")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("设置")
                .font(.headline)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .opacity(0)
                Text("返回")
                    .font(.system(size: 13))
                    .opacity(0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var settingsContent: some View {
        VStack(spacing: 12) {
            launchAtLoginRow
            shortcutRow
            obsidianRow
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var launchAtLoginRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("开机自启动")
                    .font(.system(size: 14, weight: .medium))
                Text("登录系统时自动运行 便签 Pro")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: launchAtLogin) { newValue in
                    setLaunchAtLogin(newValue)
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(10)
    }

    private var shortcutRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("全局快捷键")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }

            if !hasAccessibilityPermission {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("需要辅助功能权限才能使用全局快捷键")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("去授权") {
                            openAccessibilitySettings()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .font(.caption2)
                    }

                    Text("进程路径: \(Bundle.main.bundlePath)")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text("提示: 开发者版本请给 Terminal.app 授权，或安装 .app 版本")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(6)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text("辅助功能权限已授权")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.08))
                .cornerRadius(6)
            }

            ForEach(ShortcutAction.allCases, id: \.self) { action in
                actionShortcutRow(action)
            }

            if isRecordingAction != nil {
                Text("请按下想要的快捷键组合，按 Esc 取消")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(10)
    }

    private func actionShortcutRow(_ action: ShortcutAction) -> some View {
        HStack(spacing: 8) {
            Text(action.displayName)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(GlobalShortcutManager.shared.shortcutDisplay(for: action))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isRecordingAction == action ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12))
                .foregroundStyle(isRecordingAction == action ? Color.accentColor : .primary)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isRecordingAction == action ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )

            Spacer()

            Button(isRecordingAction == action ? "取消" : "修改") {
                if isRecordingAction == action {
                    ShortcutRecorder.shared.stopRecording()
                    isRecordingAction = nil
                } else {
                    isRecordingAction = action
                    ShortcutRecorder.shared.startRecording { config in
                        if let config = config {
                            GlobalShortcutManager.shared.setShortcut(action: action, config: config)
                        }
                        isRecordingAction = nil
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .font(.system(size: 12))

            if GlobalShortcutManager.shared.shortcut(for: action) != nil {
                Button("清除") {
                    GlobalShortcutManager.shared.clearShortcut(for: action)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    private var obsidianRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Obsidian 同步")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }

            HStack(spacing: 8) {
                Text(obsidianVaultPath.isEmpty ? "未选择 Vault" : obsidianVaultPath)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button("选择 Vault") {
                    selectObsidianVault()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(10)
    }

    private func selectObsidianVault() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择 Obsidian Vault 文件夹"

        if panel.runModal() == .OK, let url = panel.url {
            obsidianVaultPath = url.path
            ObsidianSyncManager.shared.vaultPath = url.path
        }
    }
}

// MARK: - Shortcut Config

enum ShortcutAction: String, Codable, CaseIterable {
    case togglePopover = "togglePopover"
    case createStickyNote = "createStickyNote"

    var displayName: String {
        switch self {
        case .togglePopover: return "呼出白板"
        case .createStickyNote: return "新建桌面便签"
        }
    }

    var notificationName: Notification.Name {
        switch self {
        case .togglePopover: return .toggleQuickNotePopover
        case .createStickyNote: return .createQuickNoteSticky
        }
    }
}

struct ShortcutConfig: Codable {
    var modifiers: UInt
    var keyCode: UInt16
}

class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()
    private let defaultsKey = "quicknote.shortcut.bindings"
    private var runLoopSource: CFRunLoopSource?
    private var tap: CFMachPort?

    var bindings: [ShortcutAction: ShortcutConfig] {
        get {
            guard let data = UserDefaults.standard.data(forKey: defaultsKey),
                  let dict = try? JSONDecoder().decode([String: ShortcutConfig].self, from: data)
            else { return [:] }
            var result: [ShortcutAction: ShortcutConfig] = [:]
            for (key, config) in dict {
                if let action = ShortcutAction(rawValue: key) {
                    result[action] = config
                }
            }
            return result
        }
        set {
            var dict: [String: ShortcutConfig] = [:]
            for (action, config) in newValue {
                dict[action.rawValue] = config
            }
            if let data = try? JSONEncoder().encode(dict) {
                UserDefaults.standard.set(data, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
            register()
        }
    }

    func shortcut(for action: ShortcutAction) -> ShortcutConfig? {
        bindings[action]
    }

    func shortcutDisplay(for action: ShortcutAction) -> String {
        guard let config = bindings[action] else { return "未设置" }
        return formatShortcut(config)
    }

    func setShortcut(action: ShortcutAction, config: ShortcutConfig) {
        var updated = bindings
        updated[action] = config
        bindings = updated
    }

    func clearShortcut(for action: ShortcutAction) {
        var updated = bindings
        updated.removeValue(forKey: action)
        bindings = updated
    }

    func register() {
        unregister()
        guard !bindings.isEmpty else { return }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                return GlobalShortcutManager.handleEvent(proxy: proxy, type: type, event: event, refcon: refcon)
            },
            userInfo: nil
        ) else {
            print("CGEventTap 创建失败，请检查辅助功能权限")
            return
        }

        self.tap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        self.runLoopSource = runLoopSource
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func unregister() {
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            self.tap = nil
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
    }

    private static func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let rawFlags = event.flags.rawValue
        let relevantFlags = rawFlags & (CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskControl.rawValue | CGEventFlags.maskShift.rawValue)

        for (action, config) in GlobalShortcutManager.shared.bindings {
            if keyCode == config.keyCode && relevantFlags == UInt64(config.modifiers) {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: action.notificationName, object: nil)
                }
                return nil
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func formatShortcut(_ config: ShortcutConfig) -> String {
        let modifiers = NSEvent.ModifierFlags(rawValue: config.modifiers)
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        parts.append(keyCodeToString(config.keyCode))
        return parts.joined(separator: " + ")
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Esc"
        case 65: return "."
        case 67: return "*"
        case 69: return "+"
        case 71: return "Clear"
        case 75: return "/"
        case 76: return "Return"
        case 78: return "-"
        case 81: return "="
        case 82: return "0"
        case 83: return "1"
        case 84: return "2"
        case 85: return "3"
        case 86: return "4"
        case 87: return "5"
        case 88: return "6"
        case 89: return "7"
        case 91: return "8"
        case 92: return "9"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 105: return "F13"
        case 106: return "F14"
        case 107: return "F10"
        case 109: return "F12"
        case 111: return "F15"
        case 113: return "Home"
        case 114: return "PgUp"
        case 115: return "Delete"
        case 116: return "F4"
        case 117: return "End"
        case 118: return "F2"
        case 119: return "PgDn"
        case 120: return "F1"
        case 121: return "Left"
        case 122: return "Right"
        case 123: return "Down"
        case 124: return "Up"
        default: return "Key \(keyCode)"
        }
    }
}

class ShortcutRecorder {
    static let shared = ShortcutRecorder()
    private var monitor: Any?
    private var completion: ((ShortcutConfig?) -> Void)?

    func startRecording(completion: @escaping (ShortcutConfig?) -> Void) {
        self.completion = completion
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }

            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let keyCode = event.keyCode

            // Esc to cancel
            if keyCode == 53 {
                self.completion?(nil)
                self.stopRecording()
                return nil
            }

            // Ignore pure modifier keys
            if keyCode == 55 || keyCode == 56 || keyCode == 58 || keyCode == 59 || keyCode == 60 || keyCode == 61 {
                return event
            }

            guard modifiers != [] else { return event }

            let config = ShortcutConfig(modifiers: modifiers.rawValue, keyCode: keyCode)
            self.completion?(config)
            self.stopRecording()
            return nil
        }
    }

    func stopRecording() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        completion = nil
    }
}

extension Notification.Name {
    static let toggleQuickNotePopover = Notification.Name("toggleQuickNotePopover")
    static let createQuickNoteSticky = Notification.Name("createQuickNoteSticky")
}

struct NoScrollbarScrollView<Content: View>: NSViewRepresentable {
    @ViewBuilder var content: Content

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.verticalScroller = nil
        scrollView.horizontalScroller = nil
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        let hostingView = NSHostingView(rootView: content)
        hostingView.autoresizingMask = [.width]
        hostingView.translatesAutoresizingMaskIntoConstraints = true

        scrollView.documentView = hostingView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        nsView.hasVerticalScroller = false
        nsView.verticalScroller = nil

        if let hostingView = nsView.documentView as? NSHostingView<Content> {
            hostingView.rootView = content

            let width = nsView.contentView.bounds.width
            let size = hostingView.fittingSize
            let height = max(size.height, nsView.contentView.bounds.height)
            hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        }
    }
}
