import SwiftUI
import ServiceManagement
@preconcurrency import ApplicationServices

struct SettingsView: View {
    @ObservedObject var store: NoteStore
    var onClose: () -> Void
    @State private var launchAtLogin = false
    @State private var showFloatingIsland = true
    @State private var windowSnapEnabled = true
    @State private var isRecordingAction: ShortcutAction? = nil
    @State private var hasAccessibilityPermission = false
    @ObservedObject var shortcutManager = GlobalShortcutManager.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.vertical, showsIndicators: false) {
                settingsContent
            }
        }
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
            showFloatingIsland = UserDefaults.standard.bool(forKey: Constants.showFloatingIslandKey)
            windowSnapEnabled = UserDefaults.standard.object(forKey: Constants.windowSnapEnabledKey) as? Bool ?? true
            checkAccessibilityPermission()
            GlobalShortcutManager.shared.register()
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
            Button(action: { withAnimation(.easeInOut(duration: Constants.animationMedium)) { onClose() } }) {
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

            // 占位保持标题居中
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
            floatingIslandRow
            windowSnapRow
            shortcutRow
            Spacer()
            quitButton
            versionText
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var quitButton: some View {
        Button(action: { NSApp.terminate(nil) }) {
            Text("退出应用")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.12))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var versionText: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return Text("版本 \(version)")
            .font(.caption2)
            .foregroundStyle(.secondary.opacity(0.6))
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

    private var floatingIslandRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("显示灵动岛")
                    .font(.system(size: 14, weight: .medium))
                Text("在屏幕顶部显示便签快捷入口")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $showFloatingIsland)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: showFloatingIsland) { newValue in
                    UserDefaults.standard.set(newValue, forKey: Constants.showFloatingIslandKey)
                    NotificationCenter.default.post(name: .floatingIslandSettingChanged, object: nil)
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(10)
    }

    private var windowSnapRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("窗口吸附")
                    .font(.system(size: 14, weight: .medium))
                Text("拖动便签时自动吸附屏幕边缘和其他窗口")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $windowSnapEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: windowSnapEnabled) { newValue in
                    UserDefaults.standard.set(newValue, forKey: Constants.windowSnapEnabledKey)
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

            accessibilityStatusBanner

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

    @ViewBuilder
    private var accessibilityStatusBanner: some View {
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
    }

    private func actionShortcutRow(_ action: ShortcutAction) -> some View {
        HStack(spacing: 8) {
            Text(action.displayName)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            if shortcutManager.shortcut(for: action) != nil {
                Button(action: { shortcutManager.clearShortcut(for: action) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
            }

            Text(shortcutManager.shortcutDisplay(for: action))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isRecordingAction == action ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12))
                .foregroundStyle(isRecordingAction == action ? Color.accentColor : .primary)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isRecordingAction == action ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )
                .onTapGesture {
                    if isRecordingAction == action {
                        ShortcutRecorder.shared.stopRecording()
                        isRecordingAction = nil
                    } else {
                        isRecordingAction = action
                        ShortcutRecorder.shared.startRecording { config in
                            if let config = config {
                                shortcutManager.setShortcut(action: action, config: config)
                            }
                            isRecordingAction = nil
                        }
                    }
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
}
