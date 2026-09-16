import Foundation

struct AIConfiguration: Codable, Identifiable, Equatable {
    var id = UUID()
    var ai = ""
    var model = ""
    var effort = ""
}

struct Prompt: Codable, Identifiable, Equatable {
    var id = UUID()
    var title = ""
    var category = ""
    var summary = ""
    var text = ""
    var configurations = [AIConfiguration()]
    var updatedAt = Date()
    var deletedAt: Date?
}

struct Library: Codable, Equatable {
    var version = 1
    var prompts: [Prompt] = []

    // Reorder only the visible slots. Search results never displace hidden cards
    // or items in the trash, and no prompt contents/timestamps are modified.
    func moving(_ sourceID: UUID, to targetID: UUID, within visibleIDs: [UUID]) -> Library? {
        let ids = Set(visibleIDs)
        guard sourceID != targetID, ids.count == visibleIDs.count,
              ids.contains(sourceID), ids.contains(targetID) else { return nil }
        let slots = prompts.indices.filter { ids.contains(prompts[$0].id) }
        guard slots.count == ids.count, slots.allSatisfy({ prompts[$0].deletedAt == nil }) else { return nil }
        var ordered = slots.map { prompts[$0] }
        guard let source = ordered.firstIndex(where: { $0.id == sourceID }),
              let target = ordered.firstIndex(where: { $0.id == targetID }) else { return nil }
        ordered.insert(ordered.remove(at: source), at: target)
        var result = self
        for (slot, prompt) in zip(slots, ordered) { result.prompts[slot] = prompt }
        return result
    }
}

enum LibraryError: LocalizedError {
    case incompatibleVersion, invalidPrompt, duplicateIDs
    var errorDescription: String? {
        switch self {
        case .incompatibleVersion: return "Este archivo usa una versión de biblioteca no compatible."
        case .invalidPrompt: return "Cada prompt debe tener título y contenido."
        case .duplicateIDs: return "El archivo contiene identificadores repetidos."
        }
    }
}

struct LibraryFile {
    let directory: URL
    var url: URL { directory.appendingPathComponent("library.json") }
    var backupURL: URL { directory.appendingPathComponent("library.previous.json") }

    static func decode(_ data: Data) throws -> Library {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let library = try decoder.decode(Library.self, from: data)
        guard library.version == 1 else { throw LibraryError.incompatibleVersion }
        guard Set(library.prompts.map(\.id)).count == library.prompts.count else { throw LibraryError.duplicateIDs }
        for prompt in library.prompts {
            guard !prompt.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !prompt.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LibraryError.invalidPrompt }
            guard Set(prompt.configurations.map(\.id)).count == prompt.configurations.count else { throw LibraryError.duplicateIDs }
        }
        return library
    }

    static func encode(_ library: Library) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(library)
        _ = try decode(data)
        return data
    }

    func load(seed: Data) throws -> Library {
        if FileManager.default.fileExists(atPath: url.path) {
            return try Self.decode(Data(contentsOf: url))
        }
        let library = try Self.decode(seed)
        try save(library)
        return library
    }

    func save(_ library: Library) throws {
        let data = try Self.encode(library)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            let oldData = try Data(contentsOf: url)
            _ = try Self.decode(oldData)
            try oldData.write(to: backupURL, options: .atomic)
        }
        try data.write(to: url, options: .atomic)
    }

    static func merging(_ incoming: Library, into existing: Library) -> (Library, Int) {
        let known = Set(existing.prompts.map(\.id))
        let additions = incoming.prompts.filter { !known.contains($0.id) }
        return (Library(prompts: existing.prompts + additions), additions.count)
    }
}
