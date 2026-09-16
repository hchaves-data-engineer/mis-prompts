import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor final class PromptStore: ObservableObject {
    @Published var library = Library()
    @Published var errorMessage: String?
    @Published var notice = ""
    @Published var available = false
    let file: LibraryFile
    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = LibraryFile(directory: support.appendingPathComponent("Mis Prompts", isDirectory: true))
        do {
            guard let seedURL = Bundle.main.url(forResource: "Seed", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
            library = try file.load(seed: Data(contentsOf: seedURL))
            available = true
        } catch {
            errorMessage = "No se pudo abrir tu biblioteca. Tus archivos no se han reemplazado. \(error.localizedDescription)"
        }
    }
    @discardableResult func commit(_ newLibrary: Library) -> Bool {
        guard available else { return false }
        do { try file.save(newLibrary); library = newLibrary; return true }
        catch { errorMessage = "No se pudieron guardar los cambios: \(error.localizedDescription)"; return false }
    }
    @discardableResult func save(_ value: Prompt) -> Bool {
        var newLibrary = library
        var prompt = value
        prompt.title = prompt.title.trimmingCharacters(in: .whitespacesAndNewlines)
        prompt.updatedAt = Date()
        if let index = newLibrary.prompts.firstIndex(where: { $0.id == prompt.id }) { newLibrary.prompts[index] = prompt }
        else { newLibrary.prompts.insert(prompt, at: 0) }
        if commit(newLibrary) { notice = "Prompt guardado"; return true }
        return false
    }
    func trash(_ prompt: Prompt) {
        var newLibrary = library
        guard let index = newLibrary.prompts.firstIndex(where: { $0.id == prompt.id }) else { return }
        newLibrary.prompts[index].deletedAt = Date()
        if commit(newLibrary) { notice = "Prompt movido a la papelera. Puedes restaurarlo cuando quieras." }
    }
    func restore(_ prompt: Prompt) {
        var newLibrary = library
        guard let index = newLibrary.prompts.firstIndex(where: { $0.id == prompt.id }) else { return }
        newLibrary.prompts[index].deletedAt = nil
        if commit(newLibrary) { notice = "Prompt restaurado" }
    }
    func copy(_ prompt: Prompt) {
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(prompt.text, forType: .string) { notice = "Copiado: \(prompt.title)" }
        else { errorMessage = "No se pudo copiar el prompt. Inténtalo de nuevo." }
    }
    func exportLibrary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Mis-prompts-respaldo.json"
        panel.title = "Exportar biblioteca"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try LibraryFile.encode(library).write(to: url, options: .atomic); notice = "Respaldo exportado" }
        catch { errorMessage = error.localizedDescription }
    }
    func importLibrary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Importar un respaldo de Mis Prompts"
        panel.message = "Se añadirán los prompts nuevos. Los existentes se conservarán."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let incoming = try LibraryFile.decode(Data(contentsOf: url))
            let (merged, count) = LibraryFile.merging(incoming, into: library)
            if count == 0 { notice = "No hay prompts nuevos que importar" }
            else if commit(merged) { notice = "\(count) prompts importados" }
        } catch { errorMessage = "No se pudo importar el archivo: \(error.localizedDescription)" }
    }
}

@main struct MisPromptsApp: App {
    @StateObject private var store = PromptStore()
    var body: some Scene {
        Window("Mis Prompts", id: "library") {
            LibraryView().environmentObject(store).frame(minWidth: 720, minHeight: 520)
                .tint(Color(red: 0.29, green: 0.46, blue: 0.34))
                .onAppear { NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
        }
        .defaultSize(width: 1120, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nuevo prompt") { NotificationCenter.default.post(name: .newPrompt, object: nil) }
                    .keyboardShortcut("n").disabled(!store.available)
            }
            CommandGroup(after: .newItem) {
                Button("Importar respaldo…", action: store.importLibrary).disabled(!store.available)
                Button("Exportar respaldo…", action: store.exportLibrary).disabled(!store.available)
            }
            CommandGroup(replacing: .appInfo) {
                Button("Acerca de Mis Prompts") { NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Mis Prompts", .applicationVersion: "1.0", .credits: NSAttributedString(string: "Tu biblioteca personal de prompts. Guardada en este Mac.")]) }
            }
        }
    }
}

extension Notification.Name { static let newPrompt = Notification.Name("MisPrompts.newPrompt") }
enum LibrarySection: String, CaseIterable, Identifiable {
    case all = "Mis prompts", trash = "Papelera"
    var id: String { rawValue }
}

struct LibraryView: View {
    @EnvironmentObject var store: PromptStore
    @State private var section: LibrarySection = .all
    @State private var search = ""
    @State private var editPrompt: Prompt?
    @State private var readPrompt: Prompt?
    @State private var trashPrompt: Prompt?
    private var visible: [Prompt] {
        store.library.prompts.filter { prompt in
            let matchesSection = section == .all ? prompt.deletedAt == nil : prompt.deletedAt != nil
            let haystack = ([prompt.title, prompt.summary, prompt.category, prompt.text] + prompt.configurations.flatMap { [$0.ai, $0.model, $0.effort] }).joined(separator: " ")
            return matchesSection && (search.isEmpty || haystack.localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 22) {
                Label("Mis Prompts", systemImage: "books.vertical.fill").font(.headline).padding(.top, 14)
                VStack(spacing: 6) {
                    ForEach(LibrarySection.allCases) { value in
                        Button { section = value; search = "" } label: {
                            HStack { Image(systemName: value == .all ? "square.grid.2x2" : "trash"); Text(value.rawValue); Spacer(); Text(String(store.library.prompts.filter { value == .all ? $0.deletedAt == nil : $0.deletedAt != nil }.count)).foregroundStyle(.secondary) }
                                .padding(10).background(section == value ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: store.importLibrary) { Label("Importar respaldo", systemImage: "square.and.arrow.down") }.buttonStyle(.plain).disabled(!store.available)
                    Button(action: store.exportLibrary) { Label("Exportar respaldo", systemImage: "square.and.arrow.up") }.buttonStyle(.plain).disabled(!store.available)
                    Divider()
                    Label("Guardado en este Mac", systemImage: "internaldrive").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(18).frame(width: 210).background(Color(nsColor: .controlBackgroundColor))
            Divider()
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(section.rawValue).font(.largeTitle.weight(.semibold))
                        Text(section == .all ? "El texto y la configuración, siempre juntos." : "Los prompts eliminados se conservan aquí.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { editPrompt = Prompt() } label: { Label("Nuevo prompt", systemImage: "plus") }.buttonStyle(.borderedProminent).controlSize(.large).disabled(!store.available)
                }
                HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Buscar por título, IA, modelo o contenido", text: $search).textFieldStyle(.plain); if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) } }.padding(10).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                if !store.available {
                    ContentUnavailableView("Biblioteca no disponible", systemImage: "exclamationmark.folder", description: Text("No se ha reemplazado ningún archivo. Revisa el error y vuelve a abrir la aplicación."))
                } else if visible.isEmpty {
                    ContentUnavailableView(search.isEmpty ? (section == .all ? "Crea tu primer prompt" : "La papelera está vacía") : "Sin resultados", systemImage: search.isEmpty ? "square.grid.2x2" : "magnifyingglass", description: Text(search.isEmpty ? "" : "Prueba con otra palabra."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], alignment: .leading, spacing: 16) {
                            ForEach(visible) { prompt in
                                PromptCard(prompt: prompt, isTrash: section == .trash, onOpen: { readPrompt = prompt }, onEdit: { editPrompt = prompt }, onCopy: { store.copy(prompt) }, onTrash: { trashPrompt = prompt }, onRestore: { store.restore(prompt) })
                            }
                        }.padding(2)
                    }
                }
                HStack { Text(store.notice.isEmpty ? "\(visible.count) prompts" : store.notice).font(.caption).foregroundStyle(.secondary).lineLimit(2); Spacer() }
            }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newPrompt)) { _ in editPrompt = Prompt() }
        .sheet(item: $editPrompt) { prompt in PromptEditor(prompt: prompt, onSave: store.save).environmentObject(store) }
        .sheet(item: $readPrompt) { prompt in PromptReader(prompt: prompt, onCopy: { store.copy(prompt) }, onEdit: { readPrompt = nil; editPrompt = prompt }) }
        .alert("¿Mover este prompt a la papelera?", isPresented: Binding(get: { trashPrompt != nil }, set: { if !$0 { trashPrompt = nil } })) {
            Button("Cancelar", role: .cancel) { trashPrompt = nil }
            Button("Mover a la papelera", role: .destructive) { if let prompt = trashPrompt { store.trash(prompt) }; trashPrompt = nil }
        } message: { Text("\(trashPrompt?.title ?? "")\nPodrás restaurarlo desde Papelera.") }
        .alert("No se pudo completar la operación", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("Aceptar", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}

struct PromptCard: View {
    let prompt: Prompt
    let isTrash: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onTrash: () -> Void
    let onRestore: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(prompt.category.isEmpty ? "Sin categoría" : prompt.category).font(.caption).foregroundStyle(.secondary)
            Text(prompt.title).font(.title3.weight(.semibold)).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
            if !prompt.summary.isEmpty { Text(prompt.summary).foregroundStyle(.secondary).lineLimit(3) }
            Divider()
            ForEach(prompt.configurations) { config in
                VStack(alignment: .leading, spacing: 6) {
                    Text(config.ai.isEmpty ? "IA por elegir" : config.ai).font(.callout.weight(.medium)).padding(.horizontal, 7).padding(.vertical, 3).background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 5))
                    LabeledContent("Modelo", value: config.model.isEmpty ? "Por definir" : config.model).font(.callout)
                    LabeledContent("Esfuerzo", value: config.effort.isEmpty ? "Por definir" : config.effort).font(.callout)
                }
            }
            Spacer(minLength: 0)
            HStack {
                Button("Abrir", action: onOpen)
                if isTrash { Button("Restaurar", action: onRestore) }
                else {
                    Button(action: onCopy) { Label("Copiar", systemImage: "doc.on.doc") }
                    Spacer()
                    Menu {
                        Button("Editar", systemImage: "pencil", action: onEdit)
                        Button("Mover a la papelera", systemImage: "trash", role: .destructive, action: onTrash)
                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 24).help("Editar o eliminar prompt")
                }
            }
        }.padding(20).frame(maxWidth: .infinity, minHeight: 282, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.09)))
    }
}

struct PromptEditor: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: PromptStore
    @State var prompt: Prompt
    let onSave: (Prompt) -> Bool
    var valid: Bool { !prompt.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !prompt.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(store.library.prompts.contains(where: { $0.id == prompt.id }) ? "Editar prompt" : "Nuevo prompt").font(.title2.weight(.semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    labeled("Título *") { TextField("Por ejemplo: Resumir una reunión", text: $prompt.title) }
                    HStack(alignment: .top, spacing: 14) {
                        labeled("Categoría") { TextField("Por ejemplo: Escritura", text: $prompt.category) }
                        labeled("Cuándo usarlo") { TextField("Una frase para recordarlo", text: $prompt.summary) }
                    }
                    HStack { Text("Configuración de IA").font(.headline); Spacer(); Button { prompt.configurations.append(AIConfiguration()) } label: { Label("Añadir otra IA", systemImage: "plus") } }
                    ForEach($prompt.configurations) { $config in
                        HStack(alignment: .bottom, spacing: 10) {
                            labeled("IA") { TextField("Claude, Codex, Gemini…", text: $config.ai) }
                            labeled("Modelo") { TextField("Identificador del modelo", text: $config.model) }
                            labeled("Esfuerzo") { TextField("High, Medium…", text: $config.effort) }
                            if prompt.configurations.count > 1 { Button { prompt.configurations.removeAll { $0.id == config.id } } label: { Image(systemName: "minus.circle") }.help("Quitar esta configuración") }
                        }.padding(12).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                    }
                    Text("Estos campos te recuerdan la configuración; no cambian el modelo de otras aplicaciones.").font(.caption).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prompt completo *").font(.callout.weight(.medium))
                        TextEditor(text: $prompt.text).font(.body).padding(8).frame(minHeight: 260).background(Color(nsColor: .textBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.14)))
                    }
                }.textFieldStyle(.roundedBorder).padding(2)
            }
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
            HStack { Text("Se guardará en este Mac.").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction); Button("Guardar") { if onSave(prompt) { dismiss() } }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(!valid) }
        }.padding(24).frame(width: 760, height: 680)
    }
    func labeled<V: View>(_ title: String, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(title).font(.callout.weight(.medium)); content() }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PromptReader: View {
    @Environment(\.dismiss) var dismiss
    let prompt: Prompt
    let onCopy: () -> Void
    let onEdit: () -> Void
    @State private var copied = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(prompt.title).font(.title2.weight(.semibold))
            if !prompt.summary.isEmpty { Text(prompt.summary).foregroundStyle(.secondary) }
            ScrollView { Text(prompt.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(18) }.background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            HStack { if prompt.deletedAt == nil { Button("Editar") { onEdit() } }; Spacer(); Button("Cerrar") { dismiss() }.keyboardShortcut(.cancelAction); Button { onCopy(); copied = true } label: { Label(copied ? "Copiado" : "Copiar prompt", systemImage: copied ? "checkmark" : "doc.on.doc") }.buttonStyle(.borderedProminent) }
        }.padding(24).frame(width: 740, height: 620)
    }
}
