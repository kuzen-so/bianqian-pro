import Foundation
import SwiftUI
import AppKit
@preconcurrency import ApplicationServices

@MainActor
class GlobalShortcutManager: ObservableObject {
    static let shared = GlobalShortcutManager()
    private let defaultsKey = Constants.shortcutBindingsKey
    private var runLoopSource: CFRunLoopSource?
    private var tap: CFMachPort?
    private var retryTimer: Timer?
    private var retryCount = 0
    private let maxRetries = 5

    /// 事件 tap 回调运行在非主线程，且会在每次系统按键时触发。
    /// 这里缓存一份不依赖 actor 的 bindings 快照，避免在热路径上反复解码
    /// UserDefaults 中的 JSON，也避免跨线程访问 @MainActor 单例。
    private struct CachedBinding {
        let name: Notification.Name
        let keyCode: UInt16
        let modifiers: UInt64
    }
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cachedBindings: [CachedBinding] = []

    private func updateCache(_ bindings: [ShortcutAction: ShortcutConfig]) {
        let snapshot = bindings.map { action, config in
            CachedBinding(name: action.notificationName, keyCode: config.keyCode, modifiers: UInt64(config.modifiers))
        }
        Self.cacheLock.lock()
        Self.cachedBindings = snapshot
        Self.cacheLock.unlock()
    }

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
            objectWillChange.send()
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
        let current = bindings
        updateCache(current)
        guard !current.isEmpty else { return }

        // CGEventTap 需要辅助功能权限；登录启动时权限上下文可能尚未就绪，
        // 因此失败时会自动重试，并在应用变为活跃时重新注册。
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
            print("辅助功能权限未授予，跳过全局快捷键注册")
            return
        }

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
            print("CGEventTap 创建失败，将在稍后重试")
            scheduleRetry()
            return
        }

        retryCount = 0
        self.tap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        self.runLoopSource = runLoopSource
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func unregister() {
        retryTimer?.invalidate()
        retryTimer = nil

        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            self.tap = nil
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
    }

    private func scheduleRetry() {
        guard retryCount < maxRetries else {
            print("全局快捷键注册在 \(maxRetries) 次重试后仍然失败")
            return
        }
        retryCount += 1
        let delay = TimeInterval(retryCount) * 0.5
        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.register()
            }
        }
    }

    private static func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let rawFlags = event.flags.rawValue
        let relevantFlags = rawFlags & (CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskControl.rawValue | CGEventFlags.maskShift.rawValue)

        cacheLock.lock()
        let snapshot = cachedBindings
        cacheLock.unlock()

        for binding in snapshot {
            if keyCode == binding.keyCode && relevantFlags == binding.modifiers {
                let name = binding.name
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: name, object: nil)
                }
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func formatShortcut(_ config: ShortcutConfig) -> String {
        let modifiers = NSEvent.ModifierFlags(rawValue: config.modifiers)
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        parts.append(Self.keyCodeToString(config.keyCode))
        return parts.joined(separator: " + ")
    }

    private static let keyCodeMap: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[",
        34: "I", 35: "P", 36: "Return", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
        50: "`", 51: "Delete", 53: "Esc", 65: ".", 67: "*", 69: "+", 71: "Clear",
        75: "/", 76: "Return", 78: "-", 81: "=", 82: "0", 83: "1", 84: "2", 85: "3",
        86: "4", 87: "5", 88: "6", 89: "7", 91: "8", 92: "9", 96: "F5", 97: "F6",
        98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13", 106: "F14",
        107: "F10", 109: "F12", 111: "F15", 113: "Home", 114: "PgUp", 115: "Delete",
        116: "F4", 117: "End", 118: "F2", 119: "PgDn", 120: "F1", 121: "Left",
        122: "Right", 123: "Down", 124: "Up"
    ]

    private static func keyCodeToString(_ keyCode: UInt16) -> String {
        keyCodeMap[keyCode] ?? "Key \(keyCode)"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let toggleQuickNotePopover = Notification.Name("toggleQuickNotePopover")
    static let createQuickNoteSticky = Notification.Name("createQuickNoteSticky")
    static let reopenLastStickyNote = Notification.Name("reopenLastStickyNote")
    static let toggleCollapseLastStickyNote = Notification.Name("toggleCollapseLastStickyNote")
    static let toggleCollapseStickyNote = Notification.Name("toggleCollapseStickyNote")
    static let floatingIslandSettingChanged = Notification.Name("floatingIslandSettingChanged")
}
