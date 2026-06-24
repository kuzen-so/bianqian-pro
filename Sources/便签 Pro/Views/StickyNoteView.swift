import SwiftUI

struct StickyNoteView: View {
    @State var note: Note
    @ObservedObject var store: NoteStore
    var onClose: () -> Void
    var onCreateNew: () -> Void = {}
    var onArchive: () -> Void = {}
    var onToggleCollapse: ((Bool) -> Void)? = nil

    @State private var isHovering = false
    @State private var isCollapsed = false
    @State private var formatCommand: String? = nil
    @State private var showFormatBar = false
    @Environment(\.colorScheme) var colorScheme

    /// 解析当前便签的实际背景色。`.auto` 会跟随系统模式实时变化。
    private var resolvedNoteColor: Color {
        if note.color == .auto {
            return colorScheme == .dark ? Color(white: 0.20) : Color(white: 0.90)
        }
        return note.color.swiftUIColor
    }

    private var bgColor: Color {
        if colorScheme == .dark && note.color == .auto {
            return Color(white: 0.12).opacity(0.6)
        }
        return resolvedNoteColor.opacity(0.6)
    }

    private var titleText: String {
        let trimmed = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
        var text: String
        if let first = lines.first, !first.isEmpty {
            text = String(first)
        } else {
            text = "New Note"
        }
        if text.count > Constants.UI.titleMaxLength {
            let index = text.index(text.startIndex, offsetBy: Constants.UI.titleMaxLength)
            text = String(text[..<index]) + "…"
        }
        return text
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            if !isCollapsed {
                contentArea
                    .transition(.opacity.combined(with: .move(edge: .top)))
                Spacer(minLength: 0)
                footerBar
                    .transition(.opacity)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: Constants.animationCollapseDuration), value: isCollapsed)
        .onChange(of: formatCommand) { _ in
            withAnimation(.easeInOut(duration: Constants.animationQuick)) {
                showFormatBar = false
            }
        }
        .background(bgColor)
        .onReceive(NotificationCenter.default.publisher(for: .stickyNoteEscPressed)) { notification in
            guard let id = notification.userInfo?["noteId"] as? UUID, id == note.id else { return }
            onClose()
        }
        .onReceive(NotificationCenter.default.publisher(for: .stickyNoteDoubleClicked)) { notification in
            guard let id = notification.userInfo?["noteId"] as? UUID, id == note.id else { return }
            isCollapsed.toggle()
            onToggleCollapse?(isCollapsed)
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleCollapseStickyNote)) { notification in
            guard let id = notification.userInfo?["noteId"] as? UUID, id == note.id else { return }
            isCollapsed.toggle()
            onToggleCollapse?(isCollapsed)
        }
    }

    private var titleBar: some View {
        HStack(spacing: 8) {
            Button(action: onClose) {
                Circle()
                    .fill(Color.red.opacity(0.9))
                    .frame(width: Constants.UI.closeButtonSize, height: Constants.UI.closeButtonSize)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)

            Button(action: changeColor) {
                Circle()
                    .fill(note.color.swiftUIColor)
                    .frame(width: Constants.UI.closeButtonSize, height: Constants.UI.closeButtonSize)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)

            Spacer()

            Text(titleText)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)

            Spacer()

            Button(action: onCreateNew) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: Constants.animationQuick)) {
                isHovering = hovering
            }
        }
    }

    /// 将本地 @State note 与 store 中的最新值同步，供原地更新后回读使用。
    private func syncNote() {
        note = store.notes.first(where: { $0.id == note.id }) ?? note
    }

    private var contentArea: some View {
        TransparentTextEditor(
            text: Binding(
                get: { note.content },
                set: { newValue in
                    store.updateNote(id: note.id) { $0.content = newValue }
                    syncNote()
                }
            ),
            attributedData: Binding(
                get: { note.attributedData },
                set: { newValue in
                    store.updateNote(id: note.id) { $0.attributedData = newValue }
                    syncNote()
                }
            ),
            formatCommand: $formatCommand
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .padding(.top, 4)
    }

    private var footerBar: some View {
        HStack(spacing: 6) {
            formatToggleButton

            if showFormatBar {
                formatBar
                    .transition(.opacity.combined(with: .scale))
            }

            if !showFormatBar {
                Spacer()
                characterCount
                Spacer()
            } else {
                Spacer()
            }

            Button(action: archiveNote) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    private var formatToggleButton: some View {
        Button(action: { withAnimation(.easeInOut(duration: Constants.animationQuick)) { showFormatBar.toggle() } }) {
            Text("T")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(showFormatBar ? Color.accentColor : .secondary.opacity(0.7))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
    }

    private var formatBar: some View {
        HStack(spacing: 8) {
            formatButton("bold", icon: "bold")
            formatButton("italic", icon: "italic")

            Divider()
                .frame(height: 14)

            colorFormatButton("red", color: .red)
            colorFormatButton("blue", color: .blue)
            colorFormatButton("black", color: .primary)
        }
    }

    private func formatButton(_ command: String, icon: String) -> some View {
        Button(action: { formatCommand = command; withAnimation { showFormatBar = false } }) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func colorFormatButton(_ command: String, color: Color) -> some View {
        Button(action: { formatCommand = command; withAnimation { showFormatBar = false } }) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
        }
        .buttonStyle(.plain)
    }

    private var characterCount: some View {
        Text("\(note.content.count) characters")
            .font(.system(size: 11))
            .foregroundStyle(.secondary.opacity(0.5))
    }

    private func archiveNote() {
        ScreenConfetti.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.confettiDelay) {
            self.store.archive(self.note)
            self.onArchive()
        }
    }

    private func changeColor() {
        let colors = NoteColor.selectableColors
        guard let currentIndex = colors.firstIndex(of: note.color) else { return }
        let nextIndex = (currentIndex + 1) % colors.count
        store.updateNote(id: note.id) { $0.color = colors[nextIndex] }
        syncNote()
    }
}
