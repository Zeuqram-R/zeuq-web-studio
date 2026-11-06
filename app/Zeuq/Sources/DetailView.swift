import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct DetailView: View {
    @EnvironmentObject var store: Store
    let item: FormItem
    @State private var q: Quote
    @State private var saving = false
    @State private var toast: String?

    init(item: FormItem) {
        self.item = item
        _q = State(initialValue: item.quote)
    }

    private var r: PriceResult { Pricing.compute(q, store.ajustes) }
    private var dirty: Bool { q != item.quote || item.cotizacion == nil }
    private var proposal: String { Pricing.proposal(item, q, store.ajustes) }

    var body: some View {
        Form {
            summary
            cliente
            mercado
            ForEach(Catalog.sections) { s in
                Section(s.title) {
                    ForEach(s.questions) { question in
                        QuestionRow(question: question, q: $q)
                    }
                    if s.title == "Contenido", q.blog != "no" {
                        Stepper("Artículos al lanzar: \(q.articulos)", value: $q.articulos, in: 0...30)
                    }
                }
            }
            especial
            desglose
            Section("Condiciones") {
                ForEach(Pricing.terms(q, store.ajustes), id: \.self) { Text($0).font(.callout) }
            }
            acciones
        }
        .formStyle(.grouped)
        .navigationTitle(item.nombre.isEmpty ? "Formulario" : item.nombre)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(saving ? "Guardando…" : "Guardar") { Task { await save() } }
                    .disabled(saving || !dirty)
            }
        }
        .overlay(alignment: .bottom) {
            if let t = toast {
                Text(t)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: Secciones

    private var summary: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Proyecto").foregroundStyle(.secondary)
                    Spacer()
                    if q.descuento > 0 {
                        Text(money(r.list)).strikethrough().foregroundStyle(.secondary)
                    }
                    Text(money(r.special)).font(.system(.largeTitle, design: .rounded).weight(.bold)).monospacedDigit()
                }
                HStack(alignment: .firstTextBaseline) {
                    Text("Mensual").foregroundStyle(.secondary)
                    Spacer()
                    if q.descMo > 0 { Text(money(r.monthly)).strikethrough().foregroundStyle(.secondary) }
                    Text(money(r.specialMonthly) + "/mes").font(.title2.weight(.semibold)).monospacedDigit()
                }
                if r.iva > 0 {
                    LabeledContent("Con IVA 13%", value: "\(money(r.specialIva)) · \(money(r.specialMonthlyIva))/mes")
                }
                LabeledContent("Adelanto 50%", value: money(r.deposit))
                LabeledContent("Primer año", value: money(r.firstYear))
                warnings
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder private var warnings: some View {
        let max = Textos.presupuestoMax[item.presupuesto]
        HStack(spacing: 6) {
            if q.descuento > store.ajustes.piso {
                Tag(text: "\(q.descuento - store.ajustes.piso)% por debajo de tu mínimo", color: .orange)
            } else if q.descuento > 0 {
                Tag(text: "Dentro de tu margen", color: .green)
            }
            if let max, let label = Textos.presupuesto[item.presupuesto] {
                if r.special <= max { Tag(text: "Cabe en su presupuesto (\(label))", color: .green) }
                else { Tag(text: "Arriba de su presupuesto (\(label))", color: .orange) }
            }
        }
    }

    private var cliente: some View {
        Section("Cliente") {
            if !item.rubro.isEmpty { LabeledContent("Negocio", value: item.rubro) }
            if !item.email.isEmpty {
                LabeledContent("Correo") {
                    if let u = URL(string: "mailto:\(item.email)") { Link(item.email, destination: u) } else { Text(item.email) }
                }
            }
            if !item.whatsapp.isEmpty { LabeledContent("WhatsApp", value: item.whatsapp) }
            let obj = (item.data["objetivo"]?.strings ?? []).map { Textos.objetivo[$0] ?? $0 }
            if !obj.isEmpty { LabeledContent("Objetivos", value: obj.joined(separator: ", ")) }
            if let p = Textos.presupuesto[item.presupuesto] { LabeledContent("Presupuesto", value: p) }
            if let s = item.data["sitio_actual"]?.text { LabeledContent("Página actual", value: s == "si" ? "Sí, quiere una nueva" : "No tiene") }
            if let t = item.data["referencias"]?.text, !t.isEmpty { LabeledContent("Referencias") { Text(t).textSelection(.enabled) } }
            if let t = item.data["comentarios"]?.text, !t.isEmpty { LabeledContent("Comentarios") { Text(t).textSelection(.enabled) } }
            LabeledContent("Confirmación", value: item.confirmado == nil ? "En camino" : "Enviada")
        }
    }

    private var mercado: some View {
        Section {
            Picker("Mercado", selection: $q.mercado) {
                Text("Florida / EE. UU.").tag("fl")
                Text("Costa Rica").tag("cr")
            }
            .pickerStyle(.segmented)
            .onChange(of: q.mercado) { _, m in if m == "fl" { q.iva = "no" } }
            if q.mercado == "cr" {
                Toggle("Sumar IVA 13%", isOn: Binding(get: { q.iva == "si" }, set: { q.iva = $0 ? "si" : "no" }))
            }
        } header: {
            Text("Mercado del cliente")
        } footer: {
            Text("Cambia todas las tarifas al mercado del cliente.")
        }
    }

    private var especial: some View {
        Section {
            VStack(alignment: .leading) {
                HStack { Text("Descuento proyecto"); Spacer(); Text("\(q.descuento)%").monospacedDigit() }
                Slider(value: Binding(get: { Double(q.descuento) }, set: { q.descuento = Int($0) }), in: 0...50, step: 5)
            }
            VStack(alignment: .leading) {
                HStack { Text("Descuento mensual"); Spacer(); Text("\(q.descMo)%").monospacedDigit() }
                Slider(value: Binding(get: { Double(q.descMo) }, set: { q.descMo = Int($0) }), in: 0...40, step: 5)
            }
            LabeledContent("Tu mínimo (−\(store.ajustes.piso)%)", value: money(r.floor))
        } header: {
            Text("Precio especial")
        } footer: {
            Text("Tu margen para familia y amigos. El mínimo lo cambias en Ajustes.")
        }
    }

    private var desglose: some View {
        Section {
            DisclosureGroup("Desglose del proyecto · \(money(r.list))") {
                ForEach(r.lines) { l in LabeledContent(l.text, value: money(l.amount)).font(.callout) }
                if !r.adjustments.isEmpty {
                    LabeledContent("Subtotal", value: money(r.subtotal)).font(.callout)
                    ForEach(r.adjustments) { l in LabeledContent(l.text, value: "+" + money(l.amount)).font(.callout) }
                }
            }
            DisclosureGroup("Desglose mensual · \(money(r.monthly))") {
                ForEach(r.monthlyLines) { l in LabeledContent(l.text, value: l.amount > 0 ? money(l.amount) : "Incluido").font(.callout) }
            }
        }
    }

    private var acciones: some View {
        Section {
            Button { copy(proposal) } label: { Label("Copiar propuesta", systemImage: "doc.on.doc") }
            ShareLink(item: proposal) { Label("Compartir propuesta", systemImage: "square.and.arrow.up") }
            if let wa = whatsappURL {
                Link(destination: wa) { Label("Mandar por WhatsApp", systemImage: "message") }
            }
            if item.confirmado == nil {
                Button { Task { if await store.runConfirmations() { show("Confirmación en camino") } } } label: {
                    Label("Enviar confirmación ahora", systemImage: "envelope")
                }
            }
            if item.estado != "procesado" {
                Button { Task { await save(estado: "procesado") } } label: { Label("Marcar como procesado", systemImage: "checkmark.circle") }
            }
            if item.estado != "archivado" {
                Button(role: .destructive) { Task { await store.setEstado(item, "archivado") } } label: { Label("Archivar", systemImage: "archivebox") }
            } else {
                Button { Task { await store.setEstado(item, "nuevo") } } label: { Label("Restaurar", systemImage: "arrow.uturn.backward") }
            }
        }
    }

    // MARK: Acciones

    private var whatsappURL: URL? {
        let digits = item.whatsapp.filter(\.isNumber)
        guard digits.count >= 8 else { return nil }
        let number = digits.count == 8 ? "506" + digits : digits
        let text = proposal.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://wa.me/\(number)?text=\(text)")
    }

    private func save(estado: String? = nil) async {
        saving = true
        var it = item
        it.cotizacion = q
        if let estado { it.estado = estado }
        let ok = await store.save(it, note: estado == "procesado" ? "Formulario procesado" : "Cotización guardada")
        saving = false
        show(ok ? (estado == "procesado" ? "Procesado" : "Guardado") : (store.message ?? "No se pudo guardar"))
    }

    private func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        show("Propuesta copiada")
    }

    private func show(_ t: String) {
        withAnimation { toast = t }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { if toast == t { toast = nil } }
        }
    }
}

/// Una pregunta del catálogo: lista de opciones (una) o interruptores (varias), con su precio.
struct QuestionRow: View {
    let question: Question
    @Binding var q: Quote

    var body: some View {
        if question.multi {
            VStack(alignment: .leading, spacing: 6) {
                Text(question.label).font(.subheadline.weight(.semibold))
                ForEach(question.opts) { o in
                    Toggle(isOn: Binding(
                        get: { Pricing.list(q, question.id).contains(o.v) },
                        set: { Pricing.toggle(&q, question.id, o.v, $0) })) {
                        HStack {
                            Text(o.t)
                            Spacer()
                            Text(Pricing.chip(o, mercado: q.mercado)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Picker(question.label, selection: Binding(
                    get: { Pricing.value(q, question.id) },
                    set: { Pricing.setValue(&q, question.id, $0) })) {
                    ForEach(question.opts) { o in
                        let c = Pricing.chip(o, mercado: q.mercado)
                        Text(c.isEmpty ? o.t : "\(o.t) · \(c)").tag(o.v)
                    }
                }
                if let h = question.help { Text(h).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}
