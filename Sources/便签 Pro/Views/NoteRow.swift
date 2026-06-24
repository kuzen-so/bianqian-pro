import SwiftUI

// MARK: - Shared Components

struct TagList: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tags, id: \.self) { tag in
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

struct ColorPickerMenu: View {
    let note: Note
    let store: NoteStore

    var body: some View {
        Menu("颜色") {
            ForEach(NoteColor.selectableColors, id: \.self) { color in
                Button(action: {
                    store.updateNote(id: note.id) { $0.color = color }
                }) {
                    HStack(spacing: 6) {
                        if color == .auto {
                            Image(systemName: "circle.dashed")
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(color.swiftUIColor)
                                .imageScale(.large)
                        }
                        Text(color.displayName)
                            .font(.system(size: 12))
                    }
                }
            }
        }
    }
}

// MARK: - Note Row (Active)

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
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 4) {
                    Text(dateText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if !note.tags.isEmpty {
                        TagList(tags: note.tags)
                    }
                }
            }

            Spacer()

            Button(action: { store.archive(note) }) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary.opacity(isHovering ? 0.8 : 0.3))
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(.vertical, 10)
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
            ColorPickerMenu(note: note, store: store)
            Button("添加标签") {
                onAddTag()
            }
            Divider()
            Button("删除", role: .destructive) {
                store.delete(note)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: Constants.animationQuick)) {
                isHovering = hovering
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Archived Note Row

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
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text(dateText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if !note.tags.isEmpty {
                        TagList(tags: note.tags)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
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
            ColorPickerMenu(note: note, store: store)
            Button("添加标签") {
                onAddTag()
            }
            Divider()
            Button("删除", role: .destructive) {
                store.delete(note)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
