import SwiftUI

struct InboxView: View {
    @EnvironmentObject var store: Store
    @State private var tab = "nuevo"
    @State private var selection: String?
    @State private var showSettings = false

    private var list: [FormItem] { store.items(estado: tab) }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                Picker("Estado", selection: $tab) {
                    Text("Nuevos \(count("nuevo"))").tag("nuevo")
                    Text("Procesados").tag("procesado")
                    Text("Archivados").tag("archivado")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                List(selection: $selection) {
                    if let m = store.message {
                        Label(m, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    if list.isEmpty {
                        ContentUnavailableView(tab == "nuevo" ? "Sin formularios nuevos" : "Nada por aquí",
                                               systemImage: "tray",
                                               description: Text(tab == "nuevo" ? "Cuando un cliente llene el formulario, aparece aquí." : ""))
                    }
                    ForEach(list) { item in
                        NavigationLink(value: item.id) { FormRow(item: item) }
                    }
                }
                .refreshable { await store.refresh() }
            }
            .navigationTitle("Zeuq")
            .toolbar {
                ToolbarItem {
                    Button { Task { await store.refresh() } } label: {
                        if store.loading { ProgressView() } else { Label("Actualizar", systemImage: "arrow.clockwise") }
                    }
                    .keyboardShortcut("r")
                }
                ToolbarItem {
                    Button { showSettings = true } label: { Label("Ajustes", systemImage: "gearshape") }
                }
            }
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 300, ideal: 340)
            #endif
        } detail: {
            if let id = selection, let item = store.items.first(where: { $0.id == id }) {
                DetailView(item: item).id(item.id)
            } else {
                ContentUnavailableView("Elige un formulario", systemImage: "doc.text.magnifyingglass",
                                       description: Text("Toca un formulario para ver al cliente y armar su cotización."))
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .task {
            // Mientras la app está abierta, revisa cada 5 minutos
            while !Task.isCancelled {
                await store.refresh()
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    private func count(_ e: String) -> String {
        let n = store.items(estado: e).count
        return n > 0 ? "(\(n))" : ""
    }
}

struct FormRow: View {
    let item: FormItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.titulo).font(.headline)
            Text([item.rubro, item.date.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? ""]
                .filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Tag(text: item.lang == "en" ? "Inglés" : "Español")
                if let p = Textos.presupuesto[item.presupuesto] { Tag(text: p) }
                if item.confirmado != nil {
                    Tag(text: "Confirmado", color: .green)
                } else {
                    Tag(text: "Confirmación en camino", color: .orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct Tag: View {
    let text: String
    var color: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
