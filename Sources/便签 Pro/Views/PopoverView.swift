import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: NoteStore
    @Environment(\.colorScheme) var colorScheme
    @State private var newNoteText = ""
    @State private var selectedColor: NoteColor = systemDefaultNoteColor()
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
            .frame(width: Constants.popoverSize.width, height: Constants.popoverSize.height)
            .background(.regularMaterial)

            if showSettings {
                SettingsView(store: store, onClose: { showSettings = false })
                    .frame(width: Constants.popoverSize.width, height: Constants.popoverSize.height)
                    .background(.regularMaterial)
                    .transition(.move(edge: .trailing))
            }
        }
        .onAppear {
            selectedColor = systemDefaultNoteColor()
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

            Button(action: { withAnimation(.easeInOut(duration: Constants.animationMedium)) { showSettings = true } }) {
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
            tabButton("活跃", isActive: !showArchived) { showArchived = false }
            tabButton("完成", isActive: showArchived) { showArchived = true }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func tabButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(.system(size: 12, weight: isActive ? .semibold : .regular))
            .foregroundStyle(isActive ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isActive ? Color.gray.opacity(0.15) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    private var inputArea: some View {
        VStack(spacing: 8) {
            ReturnToSubmitTextEditor(text: $newNoteText, onSubmit: addNote)
                .frame(height: 60)
                .padding(8)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )

            HStack(spacing: 8) {
                Button(action: addNote) {
                    Text("添加便签")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: createStickyNote) {
                    Text("显示便签")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
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
        store.updateNote(id: note.id) { $0.isSticky = true }
        if let updated = store.notes.first(where: { $0.id == note.id }) {
            onCreateSticky(updated)
        }
    }

    private func restoreNote(_ note: Note) {
        store.updateNote(id: note.id) {
            $0.isArchived = false
            $0.isSticky = true
        }
        if let updated = store.notes.first(where: { $0.id == note.id }) {
            onCreateSticky(updated)
        }
    }
}
