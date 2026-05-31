import Foundation
import Combine

class NoteStore: ObservableObject {
    @Published var notes: [Note] = []

    private let saveKey = "quicknote.saved.notes"

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

// MARK: - Obsidian Sync

class ObsidianSyncManager {
    static let shared = ObsidianSyncManager()
    private let vaultKey = "quicknote.obsidian.vault"

    var vaultPath: String? {
        get { UserDefaults.standard.string(forKey: vaultKey) }
        set { UserDefaults.standard.set(newValue, forKey: vaultKey) }
    }

    /// 同步单条笔记到 Obsidian（右键菜单调用）
    func syncSingleNote(_ note: Note) {
        guard let vaultPath = vaultPath else { return }
        let vaultURL = URL(fileURLWithPath: vaultPath)
        createNewDocument(note: note, in: vaultURL)
    }

    private func createNewDocument(note: Note, in vaultURL: URL) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "QuickNote_\(dateFormatter.string(from: note.createdAt)).md"
        let fileURL = vaultURL.appendingPathComponent(filename)

        var mdContent = "---\n"
        mdContent += "date: \(ISO8601DateFormatter().string(from: note.createdAt))\n"
        mdContent += "source: 便签 Pro\n"
        if !note.tags.isEmpty {
            mdContent += "tags: [\(note.tags.joined(separator: ", "))]\n"
        }
        mdContent += "---\n\n"
        mdContent += note.content

        if !note.tags.isEmpty {
            mdContent += "\n\n" + note.tags.map { "#\($0)" }.joined(separator: " ")
        }

        try? mdContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func sync(notes: [Note]) {
        guard let vaultPath = vaultPath else { return }
        let vaultURL = URL(fileURLWithPath: vaultPath)
        let syncFolder = vaultURL.appendingPathComponent("QuickNote")

        do {
            try FileManager.default.createDirectory(at: syncFolder, withIntermediateDirectories: true)
        } catch {
            print("创建 Obsidian 同步目录失败: \(error)")
            return
        }

        // 清理旧文件（重新全量同步，避免重复）
        if let existingFiles = try? FileManager.default.contentsOfDirectory(at: syncFolder, includingPropertiesForKeys: nil) {
            for file in existingFiles where file.pathExtension == "md" {
                try? FileManager.default.removeItem(at: file)
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        for note in notes where !note.isArchived {
            let filename = "\(dateFormatter.string(from: note.createdAt))_\(note.id.uuidString.prefix(8)).md"
            let fileURL = syncFolder.appendingPathComponent(filename)

            var mdContent = note.content

            // 添加元数据 Frontmatter
            mdContent = "---\n"
            mdContent += "date: \(ISO8601DateFormatter().string(from: note.createdAt))\n"
            mdContent += "source: 便签 Pro\n"
            if !note.tags.isEmpty {
                mdContent += "tags: [\(note.tags.joined(separator: ", "))]\n"
            }
            mdContent += "---\n\n"
            mdContent += note.content

            // 标签追加
            if !note.tags.isEmpty {
                mdContent += "\n\n" + note.tags.map { "#\($0)" }.joined(separator: " ")
            }

            try? mdContent.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}
