import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct InboxView: View {
    @EnvironmentObject var store: Store
    @State private var tab = "nuevos"
    @State private var selection: String?
    @State private var showSettings = false
    @State private var showResumen = false

    private var list: [FormItem] { store.items(grupo: tab) }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                Picker("Estado", selection: $tab) {
                    ForEach(Etapa.grupos, id: \.id) { g in
                        Text(g.nombre + count(g.id)).tag(g.id)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                List(selection: $selection) {
                    ForEach(store.avisos) { a in
                        VStack(alignment: .leading, spacing: 3) {
                            Label(a.titulo, systemImage: "exclamationmark.shield.fill").font(.callout.weight(.semibold)).foregroundStyle(.orange)
                            Text(a.detalle).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    if let m = store.message {
                        Label(m, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    if list.isEmpty {
                        ContentUnavailableView(emptyTitle, systemImage: "tray", description: Text(emptyText))
                    }
                    ForEach(list) { item in
                        NavigationLink(value: item.id) { FormRow(item: item) }
                    }
                }
                .refreshable { await store.refresh() }
            }
            .navigationTitle("Zeuq's Tools")
            .toolbar {
                ToolbarItem {
                    Button { Task { await store.refresh() } } label: {
                        if store.loading { ProgressView() } else { Label("Actualizar", systemImage: "arrow.clockwise") }
                    }
                    .keyboardShortcut("r")
                }
                ToolbarItem {
                    ShareFormMenu()
                }
                ToolbarItem {
                    Button { showResumen = true } label: { Label("Resumen", systemImage: "chart.bar.xaxis") }
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
        .sheet(isPresented: $showResumen) { ResumenView() }
        .task {
            // Mientras la app está abierta, revisa cada 5 minutos
            while !Task.isCancelled {
                await store.refresh()
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    private func count(_ g: String) -> String {
        guard g == "nuevos" || g == "curso" else { return "" }
        let n = store.items(grupo: g).count
        return n > 0 ? " (\(n))" : ""
    }

    private var emptyTitle: String {
        switch tab {
        case "nuevos": return "Sin formularios nuevos"
        case "curso": return "Nada en curso"
        case "clientes": return "Todavía no hay clientes"
        default: return "Nada por aquí"
        }
    }

    private var emptyText: String {
        switch tab {
        case "nuevos": return "Cuando un cliente llene el formulario, aparece aquí."
        case "curso": return "Aquí van las cotizaciones y propuestas hasta que entregas la página."
        case "clientes": return "Cuando entregues una página, el cliente pasa aquí con su mantenimiento."
        default: return "Aquí quedan las propuestas rechazadas y lo que archivaste."
        }
    }
}

struct FormRow: View {
    let item: FormItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(item.nombre.prefix(1)).uppercased())
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Etapa.color(item.estado).gradient, in: Circle())
            details
        }
        .padding(.vertical, 4)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.titulo).font(.headline)
            Text([item.rubro, item.date.map { $0.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Locale(identifier: "es_CR"))) } ?? ""]
                .filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                if item.estado != "nuevo" { Tag(text: Etapa.nombre(item.estado), color: Etapa.color(item.estado)) }
                if item.necesitaSeguimiento { Tag(text: "Dar seguimiento", color: .orange) }
                if item.mensualidadPendiente() { Tag(text: "Mensualidad pendiente", color: .orange) }
                if item.estado == "nuevo" {
                    Tag(text: item.lang == "en" ? "Inglés" : "Español")
                    if let p = Textos.presupuesto[item.presupuesto] { Tag(text: p) }
                    if item.confirmado == nil { Tag(text: "Confirmación en camino", color: .orange) }
                }
            }
        }
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


/// Botón para mandarle el formulario a un cliente nuevo, en español o en inglés.
struct ShareFormMenu: View {
    static let base = "https://zeuqram-r.github.io/zeuq-web-studio/"

    static func url(_ lang: String) -> URL { URL(string: base + "?lang=" + lang)! }

    static func mensaje(_ lang: String) -> String {
        lang == "en"
            ? "Hi! To prepare a proposal for your website, please fill out this short form (it takes about 5 to 8 minutes). You'll get a confirmation by email and your proposal within 2 business days."
            : "¡Hola! Para prepararte la propuesta de tu página web, llena este formulario corto (toma unos 5 a 8 minutos). Te llega una confirmación por correo y tu propuesta en máximo 2 días hábiles."
    }

    var body: some View {
        Menu {
            Section("Compartir el formulario") {
                ShareLink(item: Self.url("es"), message: Text(Self.mensaje("es"))) {
                    Label("En español", systemImage: "square.and.arrow.up")
                }
                ShareLink(item: Self.url("en"), message: Text(Self.mensaje("en"))) {
                    Label("En inglés", systemImage: "square.and.arrow.up")
                }
            }
            Section("Copiar solo el link") {
                Button { copiar("es") } label: { Label("Link en español", systemImage: "link") }
                Button { copiar("en") } label: { Label("Link en inglés", systemImage: "link") }
            }
        } label: {
            Label("Mandar formulario", systemImage: "paperplane")
        }
    }

    private func copiar(_ lang: String) {
        let t = Self.url(lang).absoluteString
        #if os(iOS)
        UIPasteboard.general.string = t
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(t, forType: .string)
        #endif
    }
}
