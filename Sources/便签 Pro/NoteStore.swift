import Foundation
import Combine

class NoteStore: ObservableObject {
    @Published var notes: [Note] = []

    private let saveKey = "quicknote.saved.notes"
    private let debounceInterval: TimeInterval = 0.5
    private var saveTimer: Timer?

    init() {
        load()
    }

    func add(_ content: String, color: NoteColor = .yellow, isSticky: Bool = false) {
        let note = Note(
            content: content,
            createdAt: Date(),
            color: color,
            isSticky: isSticky,
            isArchived: false,
            tags: []
        )
        notes.append(note)
        save()
    }

    func update(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            save()
        }
    }

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        save()
    }

    func archive(_ note: Note) {
        var updated = note
        updated.isArchived = true
        updated.isSticky = false
        update(updated)
    }

    func unarchive(_ note: Note) {
        var updated = note
        updated.isArchived = false
        update(updated)
    }

    func addTag(to note: Note, tag: String) {
        var updated = note
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !updated.tags.contains(trimmed) else { return }
        updated.tags.append(trimmed)
        update(updated)
    }

    func removeTag(from note: Note, tag: String) {
        var updated = note
        updated.tags.removeAll { $0 == tag }
        update(updated)
    }

    func allTags() -> [String] {
        Array(Set(notes.flatMap { $0.tags })).sorted()
    }

    func pin(_ note: Note) {
        var updated = note
        updated.isPinned = true
        update(updated)
    }

    func unpin(_ note: Note) {
        var updated = note
        updated.isPinned = false
        update(updated)
    }

    func save() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.performSave()
        }
    }

    /// 立即保存，用于应用即将终止等场景
    func flushSave() {
        saveTimer?.invalidate()
        saveTimer = nil
        performSave()
    }

    private func performSave() {
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([Note].self, from: data)
        else { return }
        notes = decoded
    }
}

