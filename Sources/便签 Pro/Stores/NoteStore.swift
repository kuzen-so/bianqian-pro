import Foundation
import Combine

class NoteStore: ObservableObject {
    @Published var notes: [Note] = []

    private let saveKey = Constants.savedNotesKey
    private var saveWorkItem: DispatchWorkItem?
    private let saveQueue = DispatchQueue(label: "com.kuzen.quicknote.save")

    init() {
        load()
    }

    // MARK: - CRUD

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

    /// 通过闭包原地更新便签，消除重复代码
    func updateNote(id: UUID, transform: (inout Note) -> Void) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        transform(&notes[index])
        save()
    }

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Archive

    func archive(_ note: Note) {
        updateNote(id: note.id) { $0.isArchived = true; $0.isSticky = false }
    }

    func unarchive(_ note: Note) {
        updateNote(id: note.id) { $0.isArchived = false }
    }

    // MARK: - Tags

    func addTag(to note: Note, tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        updateNote(id: note.id) {
            if !$0.tags.contains(trimmed) {
                $0.tags.append(trimmed)
            }
        }
    }

    func removeTag(from note: Note, tag: String) {
        updateNote(id: note.id) {
            $0.tags.removeAll { $0 == tag }
        }
    }

    func allTags() -> [String] {
        Array(Set(notes.flatMap { $0.tags })).sorted()
    }

    // MARK: - Pin

    func pin(_ note: Note) {
        updateNote(id: note.id) { $0.isPinned = true }
    }

    func unpin(_ note: Note) {
        updateNote(id: note.id) { $0.isPinned = false }
    }

    // MARK: - Persistence

    func save() {
        saveWorkItem?.cancel()
        // 在主线程对 notes 做值快照，后台队列只对快照编码并写文件，
        // 避免后台编码与主线程修改 notes 之间的数据竞争。
        let snapshot = notes
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSave(snapshot)
        }
        saveWorkItem = workItem
        saveQueue.asyncAfter(deadline: .now() + Constants.saveDebounceInterval, execute: workItem)
    }

    /// 立即保存，用于应用即将终止等场景
    func flushSave() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        performSave(notes)
    }

    private var notesFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent(Constants.appSupportDirName, isDirectory: true)
        return appDir.appendingPathComponent(Constants.notesFileName)
    }

    private func ensureNotesDirectoryExists(at directory: URL) {
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func performSave(_ snapshot: [Note]) {
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }

        let fileURL = notesFileURL
        let directory = fileURL.deletingLastPathComponent()
        ensureNotesDirectoryExists(at: directory)

        let tempURL = fileURL.appendingPathExtension("tmp")
        do {
            try encoded.write(to: tempURL, options: .atomic)
            try FileManager.default.replaceItem(at: fileURL, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
            UserDefaults.standard.removeObject(forKey: saveKey)
        } catch {
            try? encoded.write(to: fileURL, options: .atomic)
        }
    }

    func load() {
        let fileURL = notesFileURL
        let directory = fileURL.deletingLastPathComponent()
        ensureNotesDirectoryExists(at: directory)

        let hasMigrated = UserDefaults.standard.bool(forKey: Constants.migrationCompletedKey)
        if !hasMigrated {
            if let legacyData = UserDefaults.standard.data(forKey: saveKey),
               let decoded = try? JSONDecoder().decode([Note].self, from: legacyData) {
                notes = decoded
                performSave(decoded)
                UserDefaults.standard.set(true, forKey: Constants.migrationCompletedKey)
                return
            }
            UserDefaults.standard.set(true, forKey: Constants.migrationCompletedKey)
        }

        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Note].self, from: data)
        else { return }
        notes = decoded
    }
}
