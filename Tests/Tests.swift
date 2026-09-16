import Foundation

@main struct Tests {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = LibraryFile(directory: directory)
        let seed = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
        let initial = try file.load(seed: seed)
        precondition(initial.prompts.count == 7)
        let addedIndex = initial.prompts.count
        var changed = initial
        var p = Prompt(title: "Unicode ñ • <script>", category: "Prueba", summary: "", text: "Línea 1\nLínea 2 $() \"literal\"")
        p.updatedAt = Date(timeIntervalSince1970: 1700000000)
        p.configurations = [AIConfiguration(ai: "Claude", model: "test", effort: "High"), AIConfiguration(ai: "Gemini", model: "test", effort: "Medium")]
        changed.prompts.append(p)
        try file.save(changed)
        let loaded = try file.load(seed: seed)
        precondition(loaded == changed, "Persistencia entre instancias")
        changed.prompts[addedIndex].text += "\nEdición"
        changed.prompts[addedIndex].deletedAt = Date(timeIntervalSince1970: 1700000100)
        try file.save(changed)
        precondition(tryEqual(file, changed, seed), "Papelera persistente")
        changed.prompts[addedIndex].deletedAt = nil
        try file.save(changed)
        precondition(tryEqual(file, changed, seed), "Restauración persistente")
        let backup = try LibraryFile.decode(Data(contentsOf: file.backupURL))
        precondition(backup.prompts[addedIndex].deletedAt != nil, "Respaldo anterior")
        let exported = try LibraryFile.decode(LibraryFile.encode(changed))
        precondition(exported == changed, "Exportar/importar")
        let (merged, count) = LibraryFile.merging(exported, into: initial)
        precondition(count == 1 && merged.prompts.count == initial.prompts.count + 1)
        let (again, repeated) = LibraryFile.merging(exported, into: merged)
        precondition(repeated == 0 && again == merged, "Importación sin duplicados")
        let ids = initial.prompts.map(\.id)
        let moved = initial.moving(ids[0], to: ids.last!, within: ids)!
        precondition(moved.prompts == Array(initial.prompts.dropFirst()) + [initial.prompts[0]], "Mover hacia el final sin alterar contenido")
        precondition(moved.moving(ids[0], to: ids[1], within: ids) == initial, "Mover hacia el principio")
        var filtered = initial
        filtered.prompts[3].deletedAt = Date(timeIntervalSince1970: 1700000100)
        let subset = [ids[0], ids[2], ids[5]]
        let reordered = filtered.moving(ids[0], to: ids[5], within: subset)!
        precondition(reordered.prompts.map(\.id) == [ids[2], ids[1], ids[5], ids[3], ids[4], ids[0]] + Array(ids.dropFirst(6)), "Mover resultados de búsqueda")
        for index in [1, 3, 4] { precondition(reordered.prompts[index] == filtered.prompts[index], "Conservar ocultos y papelera") }
        precondition(filtered.moving(ids[0], to: ids[0], within: subset) == nil)
        precondition(filtered.moving(UUID(), to: ids[5], within: subset) == nil)
        precondition(filtered.moving(ids[0], to: ids[5], within: subset + [ids[0]]) == nil)
        precondition(filtered.moving(ids[0], to: ids[5], within: subset + [UUID()]) == nil)
        precondition(filtered.moving(ids[0], to: ids[5], within: ids) == nil, "No reordenar la papelera")
        try file.save(reordered)
        precondition(tryEqual(file, reordered, seed), "Conservar orden al recargar")
        let orderedExport = try LibraryFile.decode(LibraryFile.encode(reordered))
        precondition(orderedExport == reordered, "Conservar orden al exportar")
        precondition(LibraryFile.merging(orderedExport, into: Library()).0 == reordered, "Conservar orden al importar biblioteca vacía")
        let corrupt = Data("archivo inválido".utf8)
        try corrupt.write(to: file.url)
        do { _ = try file.load(seed: seed); fatalError("Debe rechazar datos corruptos") } catch {}
        do { try file.save(initial); fatalError("Debe conservar el archivo corrupto") } catch {}
        let retained = try Data(contentsOf: file.url)
        precondition(retained == corrupt)
        print("OK: persistencia, edición, papelera, respaldos, importación, reordenación completa y filtrada, movimientos inválidos y conservación de datos corruptos.")
    }
    static func tryEqual(_ file: LibraryFile, _ expected: Library, _ seed: Data) -> Bool {
        (try? file.load(seed: seed)) == expected
    }
}
