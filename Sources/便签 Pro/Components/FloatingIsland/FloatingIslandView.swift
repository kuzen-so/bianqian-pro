import SwiftUI

struct FloatingIslandView: View {
    @ObservedObject var store: NoteStore
    @ObservedObject var manager: FloatingIslandManager
    var onOpenNote: (Note) -> Void
    var onCreateNote: () -> Void
    var onArchiveNote: (Note) -> Void

    private var cornerRadius: CGFloat {
        manager.isExpanded ? 20 : 12
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black)
                .shadow(color: Color.black, radius: 12, x: 0, y: 4)

            // 用 if/else 确保不收起的视图完全从布局中移除，不会撑大背景
            if manager.isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: 0.15)),
                        removal: .opacity.animation(.easeIn(duration: 0.1))
                    ))
            } else {
                collapsedContent
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: 0.1)),
                        removal: .opacity.animation(.easeIn(duration: 0.08))
                    ))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .animation(.easeInOut(duration: 0.2), value: manager.isExpanded)
    }

    // MARK: - Collapsed

    private var collapsedContent: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 12))
                .foregroundColor(.white)

            Text("便签")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)

            let activeCount = store.notes.filter { !$0.isArchived }.count
            if activeCount > 0 {
                Text("\(activeCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Expanded

    private var expandedContent: some View {
        VStack(spacing: 0) {
            expandedHeader
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()
                .background(Color(white: 0.2))
                .padding(.horizontal, 16)

            noteList
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .frame(maxHeight: .infinity)

            bottomActions
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var expandedHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)

                Text("便签 Pro")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()

            Button(action: { manager.hide() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(white: 0.4))
            }
            .buttonStyle(.plain)
        }
    }

    private var noteList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                let activeNotes = store.notes
                    .filter { !$0.isArchived }
                    .sorted { $0.isPinned && !$1.isPinned }

                if activeNotes.isEmpty {
                    emptyState
                } else {
                    ForEach(activeNotes) { note in
                        islandNoteRow(note)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 28))
                .foregroundColor(Color(white: 0.4))

            Text("还没有便签")
                .font(.system(size: 13))
                .foregroundColor(Color(white: 0.5))

            Text("点击下方按钮创建一个")
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.4))
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private func islandNoteRow(_ note: Note) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(note.color.swiftUIColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(note.content.isEmpty ? "空白便签" : note.content)
                    .font(.system(size: 13))
                    .lineLimit(8)
                    .foregroundColor(.white)

                if note.isPinned {
                    HStack(spacing: 2) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                        Text("桌面显示中")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.orange)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button(action: { onOpenNote(note) }) {
                    Image(systemName: note.isPinned ? "eye.fill" : "pin")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.7))
                }
                .buttonStyle(.plain)

                Button(action: { onArchiveNote(note) }) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(white: 0.12))
        .cornerRadius(10)
    }

    private var bottomActions: some View {
        HStack(spacing: 10) {
            Button(action: onCreateNote) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("新建便签")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.accentColor)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            Spacer()

            let archiveCount = store.notes.filter { $0.isArchived }.count
            if archiveCount > 0 {
                Text("\(archiveCount) 个已完成")
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.5))
            }
        }
    }
}
