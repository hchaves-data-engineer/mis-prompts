import Foundation

@main struct Tests {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = LibraryFile(directory: directory)
        let seed = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
        let initial = try file.load(seed: seed)
        precondition(initial.prompts.count == 6)
        var changed = initial
        var p = Prompt(title: "Unicode ñ • <script>", category: "Prueba", summary: "", text: "Línea 1\nLínea 2 $() \"literal\"")
        p.updatedAt = Date(timeIntervalSince1970: 1700000000)
        p.configurations = [AIConfiguration(ai: "Claude", model: "test", effort: "High"), AIConfiguration(ai: "Gemini", model: "test", effort: "Medium")]
        changed.prompts.append(p)
        try file.save(changed)
        let loaded = try file.load(seed: seed)
        precondition(loaded == changed, "Persistencia entre instancias")
        changed.prompts[6].text += "\nEdición"
        changed.prompts[6].deletedAt = Date(timeIntervalSince1970: 1700000100)
        try file.save(changed)
        precondition(tryEqual(file, changed, seed), "Papelera persistente")
        changed.prompts[6].deletedAt = nil
        try file.save(changed)
        precondition(tryEqual(file, changed, seed), "Restauración persistente")
        let backup = try LibraryFile.decode(Data(contentsOf: file.backupURL))
        precondition(backup.prompts[6].deletedAt != nil, "Respaldo anterior")
        let exported = try LibraryFile.decode(LibraryFile.encode(changed))
        precondition(exported == changed, "Exportar/importar")
        let (merged, count) = LibraryFile.merging(exported, into: initial)
        precondition(count == 1 && merged.prompts.count == 7)
        let (again, repeated) = LibraryFile.merging(exported, into: merged)
        precondition(repeated == 0 && again == merged, "Importación sin duplicados")
        let corrupt = Data("archivo inválido".utf8)
        try corrupt.write(to: file.url)
        do { _ = try file.load(seed: seed); fatalError("Debe rechazar datos corruptos") } catch {}
        do { try file.save(initial); fatalError("Debe conservar el archivo corrupto") } catch {}
        let retained = try Data(contentsOf: file.url)
        precondition(retained == corrupt)
        print("OK: crear, guardar, recargar, editar, papelera, restaurar, respaldar, exportar/importar, evitar duplicados y conservar datos corruptos.")
    }
    static func tryEqual(_ file: LibraryFile, _ expected: Library, _ seed: Data) -> Bool {
        (try? file.load(seed: seed)) == expected
    }
}
