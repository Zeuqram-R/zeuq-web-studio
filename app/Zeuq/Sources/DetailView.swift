import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum DetailTab: String, CaseIterable, Identifiable {
    case cliente = "Cliente"
    case cotizacion = "Cotización"
    case seguimiento = "Seguimiento"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .cliente: return "person.text.rectangle"
        case .cotizacion: return "dollarsign.circle"
        case .seguimiento: return "flag.checkered"
        }
    }
}

struct DetailView: View {
    @EnvironmentObject var store: Store
    let item: FormItem
    @State private var q: Quote
    @State private var tab: DetailTab = .cliente
    @State private var saving = false
    @State private var toast: String?
    @State private var showProposal = false
    @State private var track: Track

    init(item: FormItem) {
        self.item = item
        _q = State(initialValue: item.quote)
        _track = State(initialValue: Track(item))
        _tab = State(initialValue: ["aceptada", "construccion", "entregada"].contains(item.estado) ? .seguimiento : .cliente)
    }

    private var r: PriceResult { Pricing.compute(q, store.ajustes) }
    private var dirty: Bool { q != item.quote || item.cotizacion == nil || track != Track(item) }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Vista", selection: $tab) {
                ForEach(DetailTab.allCases) { t in Label(t.rawValue, systemImage: t.icon).tag(t) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.vertical, 10)

            ScrollView {
                Group {
                    switch tab {
                    case .cliente: ClienteTab(item: item)
                    case .cotizacion: CotizacionTab(item: item, q: $q, r: r)
                    case .seguimiento:
                        SeguimientoTab(item: item, r: r, track: $track,
                                       onEstado: { e in Task { await changeEstado(e) } },
                                       onPersist: { Task { await save(quiet: true) } })
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.pageBackground)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { priceBar }
        .navigationTitle(item.nombre.isEmpty ? "Formulario" : item.nombre)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(saving ? "Guardando…" : "Guardar") { Task { await save() } }
                    .disabled(saving || !dirty)
            }
            ToolbarItem(placement: .secondaryAction) { moreMenu }
            #if os(iOS)
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .bold()
            }
            #endif
        }
        .sheet(isPresented: $showProposal) {
            ProposalSheet(item: item, q: $q, ajustes: store.ajustes, whatsappNumber: whatsappNumber,
                          onCopy: { copy($0) },
                          onSent: ["nuevo", "procesado"].contains(item.estado) ? { Task { await changeEstado("enviada") } } : nil)
        }
        .overlay(alignment: .top) {
            if let t = toast {
                Text(t)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: Barra de precio fija abajo

    private var priceBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text(r.iva > 0 ? "Proyecto · IVA incluido" : "Proyecto").font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(money(r.iva > 0 ? r.specialIva : r.special)).font(.title2.weight(.bold)).monospacedDigit()
                    if q.descuento > 0 { Text(money(r.list)).font(.caption).strikethrough().foregroundStyle(.secondary) }
                }
                if q.mercado == "cr" {
                    Text("≈ " + colones(r.iva > 0 ? r.specialIva : r.special, store.ajustes.tipoCambio)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(r.iva > 0 ? "Mensual · IVA incl." : "Mensual").font(.caption).foregroundStyle(.secondary)
                Text(money(r.iva > 0 ? r.specialMonthlyIva : r.specialMonthly)).font(.title3.weight(.semibold)).monospacedDigit()
                if q.mercado == "cr" {
                    Text("≈ " + colones(r.iva > 0 ? r.specialMonthlyIva : r.specialMonthly, store.ajustes.tipoCambio)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Spacer()
            Button { showProposal = true } label: {
                Label("Propuesta", systemImage: "paperplane.fill").font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var moreMenu: some View {
        Menu {
            if item.confirmado == nil {
                Button { Task { if await store.runConfirmations() { show("Confirmación en camino") } } } label: {
                    Label("Enviar confirmación ahora", systemImage: "envelope")
                }
            }
            if item.estado == "nuevo" {
                Button { Task { await changeEstado("procesado") } } label: { Label("Marcar como cotizado", systemImage: "checkmark.circle") }
            }
            if item.estado == "archivado" || item.estado == "rechazada" {
                Button { Task { await changeEstado("procesado") } } label: { Label("Reabrir", systemImage: "arrow.uturn.backward") }
            } else {
                Button(role: .destructive) { Task { await changeEstado("archivado") } } label: { Label("Archivar", systemImage: "archivebox") }
            }
            Divider()
            Button(role: .destructive) { q = Quote.from(item.data) } label: {
                Label("Volver a las respuestas del cliente", systemImage: "arrow.counterclockwise")
            }
        } label: {
            Label("Más", systemImage: "ellipsis.circle")
        }
    }

    // MARK: Acciones

    private var whatsappNumber: String? {
        let digits = item.whatsapp.filter(\.isNumber)
        guard digits.count >= 8 else { return nil }
        return digits.count == 8 ? "506" + digits : digits
    }

    /// El formulario con la cotización y el seguimiento que tienes en pantalla
    private var current: FormItem {
        var it = item
        it.cotizacion = q
        track.apply(to: &it)
        return it
    }

    private func save(quiet: Bool = false) async {
        saving = true
        let ok = await store.save(current, note: "Cotización y seguimiento guardados")
        saving = false
        if !quiet || !ok { show(ok ? "Guardado" : (store.message ?? "No se pudo guardar")) }
    }

    private func changeEstado(_ e: String) async {
        saving = true
        let ok = await store.setEstado(current, e)
        saving = false
        show(ok ? Etapa.nombre(e) : (store.message ?? "No se pudo guardar"))
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

// MARK: - Pestaña Cliente

struct ClienteTab: View {
    let item: FormItem

    private func answer(_ id: String) -> String {
        guard let q = Catalog.question(id) else { return "" }
        if q.multi {
            let vals = item.data[id]?.strings ?? []
            let names = vals.map { v in q.opts.first(where: { $0.v == v })?.t ?? v }
            return names.isEmpty ? "Ninguna" : names.joined(separator: ", ")
        }
        guard let v = item.data[id]?.text else { return "Sin respuesta" }
        return q.opts.first(where: { $0.v == v })?.t ?? v
    }

    private var waURL: URL? {
        let digits = item.whatsapp.filter(\.isNumber)
        guard digits.count >= 8 else { return nil }
        return URL(string: "https://wa.me/\(digits.count == 8 ? "506" + digits : digits)")
    }

    var body: some View {
        VStack(spacing: 14) {
            // Encabezado
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Text(String(item.nombre.prefix(1)).uppercased())
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor.gradient, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.nombre.isEmpty ? "Sin nombre" : item.nombre).font(.title2.weight(.bold))
                        Text([item.negocio, item.rubro].filter { !$0.isEmpty }.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Tag(text: item.lang == "en" ? "Llenó en inglés" : "Llenó en español")
                    if item.confirmado != nil { Tag(text: "Confirmación enviada", color: .green) }
                    else { Tag(text: "Confirmación en camino", color: .orange) }
                }
                HStack(spacing: 8) {
                    if let u = URL(string: "mailto:\(item.email)"), !item.email.isEmpty {
                        Link(destination: u) { Label("Correo", systemImage: "envelope.fill") }.buttonStyle(.bordered)
                    }
                    if let w = waURL {
                        Link(destination: w) { Label("WhatsApp", systemImage: "message.fill") }.buttonStyle(.bordered).tint(.green)
                    }
                }
                if let d = item.date {
                    Text("Recibido el " + d.formatted(.dateTime.day().month(.wide).year().hour().minute().locale(Locale(identifier: "es_CR")))).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Card(title: "Contacto", icon: "person.crop.circle.fill", color: .blue) {
                InfoRow(label: "Correo", value: item.email.isEmpty ? "Sin correo" : item.email)
                InfoRow(label: "WhatsApp / teléfono", value: item.whatsapp.isEmpty ? "No lo dejó" : item.whatsapp, muted: item.whatsapp.isEmpty)
            }

            Card(title: "Lo que busca", icon: "target", color: .green) {
                let obj = (item.data["objetivo"]?.strings ?? []).map { Textos.objetivo[$0] ?? $0 }
                if !obj.isEmpty {
                    FlowTags(items: obj)
                }
                InfoRow(label: "¿Tiene página?", value: item.data["sitio_actual"]?.text == "si" ? "Sí, pero quiere una nueva" : "No")
                InfoRow(label: "Presupuesto", value: Textos.presupuesto[item.presupuesto] ?? "No dijo")
                InfoRow(label: "Para cuándo", value: answer("plazo"))
                InfoRow(label: "Idioma de la página", value: answer("idioma"))
            }

            ForEach(Catalog.sections.filter { $0.title != "Idioma y plazo" }) { s in
                Card(title: s.title, icon: SectionStyle.icon(s.title), color: SectionStyle.color(s.title)) {
                    ForEach(s.questions) { question in
                        InfoRow(label: question.label, value: answer(question.id))
                    }
                    if s.title == "Contenido", let n = item.data["articulos"]?.int, n > 0 {
                        InfoRow(label: "Artículos al lanzar", value: "\(n)")
                    }
                }
            }

            if let t = item.data["referencias"]?.text, !t.isEmpty {
                Card(title: "Páginas que le gustan", icon: "link", color: .cyan) {
                    Text(t).textSelection(.enabled)
                }
            }
            if let t = item.data["comentarios"]?.text, !t.isEmpty {
                Card(title: "Comentarios", icon: "text.bubble.fill", color: .mint) {
                    Text(t).textSelection(.enabled)
                }
            }
        }
        .padding(.top, 4)
    }
}

/// Etiquetas que se acomodan en varias líneas.
struct FlowTags: View {
    let items: [String]
    var body: some View {
        ColumnsLayout(minWidth: 130, spacing: 6) {
            ForEach(items, id: \.self) { Tag(text: $0, color: .green) }
        }
    }
}

// MARK: - Pestaña Cotización

struct CotizacionTab: View {
    @EnvironmentObject var store: Store
    let item: FormItem
    @Binding var q: Quote
    let r: PriceResult

    var body: some View {
        VStack(spacing: 14) {
            resumen

            Card(title: "Mercado del cliente", icon: "mappin.and.ellipse", color: .blue,
                 subtitle: "Cambia todas las tarifas al mercado del cliente") {
                Picker("Mercado", selection: $q.mercado) {
                    Text("Florida / EE. UU.").tag("fl")
                    Text("Costa Rica").tag("cr")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: q.mercado) { _, m in if m == "fl" { q.iva = "no" } }
                if q.mercado == "cr" {
                    Toggle("Sumar IVA 13%", isOn: Binding(get: { q.iva == "si" }, set: { q.iva = $0 ? "si" : "no" }))
                }
            }

            ForEach(Catalog.sections) { s in
                Card(title: s.title, icon: SectionStyle.icon(s.title), color: SectionStyle.color(s.title)) {
                    ForEach(s.questions) { question in
                        if question.id == "modalidad" && q.reservas == "no" { EmptyView() }
                        else if (question.id == "autor") && q.blog == "no" { EmptyView() }
                        else if question.id == "artmes" && q.blog == "no" { EmptyView() }
                        else { OptionGrid(question: question, q: $q) }
                    }
                    if s.title == "Contenido", q.blog != "no" {
                        Stepper("Artículos al lanzar: \(q.articulos)", value: $q.articulos, in: 0...30)
                    }
                }
            }

            precios
            especial

            Card(title: "Condiciones", icon: "checklist", color: .gray) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Pricing.terms(q, store.ajustes), id: \.self) { t in
                        Label(t, systemImage: "circle.fill").labelStyle(BulletLabel()).font(.callout)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    // Resumen arriba
    private var resumen: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading) {
                    Text("Precio de lista").font(.caption).foregroundStyle(.secondary)
                    Text(money(r.list)).font(.title.weight(.bold)).monospacedDigit()
                    if q.mercado == "cr" {
                        Text("≈ " + colones(r.list, store.ajustes.tipoCambio)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Mensual de lista").font(.caption).foregroundStyle(.secondary)
                    Text(money(r.monthly) + "/mes").font(.title3.weight(.semibold)).monospacedDigit()
                }
            }
            HStack(spacing: 6) {
                if let label = Textos.presupuesto[item.presupuesto], let max = Textos.presupuestoMax[item.presupuesto] {
                    if r.special <= max { Tag(text: "Cabe en su presupuesto (\(label))", color: .green) }
                    else { Tag(text: "Arriba de su presupuesto (\(label))", color: .orange) }
                }
                if !q.overrides.isEmpty || !q.custom.isEmpty { Tag(text: "Con precios ajustados", color: .purple) }
                if r.iva > 0 { Tag(text: "+ IVA 13%: \(money((r.list * 1.13).rounded())) con IVA", color: .indigo) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // Precios editables de cada concepto
    private var precios: some View {
        Card(title: "Precios", icon: "pencil.and.list.clipboard", color: .purple,
             subtitle: "Toca un monto para cambiarlo. Lo que cambies queda marcado.") {
            Text("Proyecto").font(.subheadline.weight(.semibold))
            ForEach(r.lines) { l in lineRow(l) }
            if !r.adjustments.isEmpty {
                ForEach(r.adjustments) { l in
                    HStack { Text(l.text).foregroundStyle(.secondary); Spacer(); Text("+" + money(l.amount)).monospacedDigit().foregroundStyle(.secondary) }
                        .font(.callout)
                }
            }
            if r.iva > 0 {
                HStack { Text("IVA 13% (se suma al precio final)").foregroundStyle(.indigo); Spacer(); Text("+" + money((r.list * 0.13).rounded())).monospacedDigit().foregroundStyle(.indigo) }
                    .font(.callout)
            }
            Button { q.custom.append(CustomLine(text: "", amount: 0, monthly: false)) } label: {
                Label("Agregar concepto al proyecto", systemImage: "plus.circle.fill")
            }
            Divider()
            Text("Mensual").font(.subheadline.weight(.semibold))
            ForEach(r.monthlyLines) { l in lineRow(l) }
            Button { q.custom.append(CustomLine(text: "", amount: 0, monthly: true)) } label: {
                Label("Agregar concepto mensual", systemImage: "plus.circle.fill")
            }
            if !q.overrides.isEmpty {
                Button(role: .destructive) { q.overrides = [:] } label: {
                    Label("Volver a los precios calculados", systemImage: "arrow.uturn.backward")
                }
                .font(.callout)
            }
        }
    }

    @ViewBuilder private func lineRow(_ l: PriceLine) -> some View {
        if let cid = l.customID, let idx = q.custom.firstIndex(where: { $0.id == cid }) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Nombre del concepto", text: $q.custom[idx].text)
                    let clientLang = item.lang == "en" ? "en" : "es"
                    let t = q.custom[idx].text.trimmingCharacters(in: .whitespaces)
                    if !q.ignorarIdioma.contains(t), let d = IdiomaCheck.detect(t), d != clientLang {
                        HStack(spacing: 6) {
                            Label("Parece \(IdiomaCheck.nombre(d)); el cliente habla \(IdiomaCheck.nombre(clientLang))", systemImage: "character.bubble")
                                .font(.caption).foregroundStyle(.orange)
                            Button("Está bien") { q.ignorarIdioma.append(t) }.font(.caption).buttonStyle(.borderless)
                        }
                    }
                }
                AmountField(value: $q.custom[idx].amount)
                Button(role: .destructive) { q.custom.remove(at: idx) } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
            }
        } else if !l.key.isEmpty {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(l.text)
                    if let o = l.original {
                        Text("Calculado: \(money(o))").font(.caption).foregroundStyle(.purple)
                    }
                }
                Spacer()
                AmountField(value: Binding(get: { l.amount }, set: { q.overrides[l.key] = $0 }))
                if l.original != nil {
                    Button { q.overrides[l.key] = nil } label: { Image(systemName: "arrow.uturn.backward.circle") }
                        .buttonStyle(.borderless)
                }
            }
            .font(.callout)
        }
    }

    // Precio especial
    private var especial: some View {
        Card(title: "Precio especial", icon: "gift.fill", color: .green,
             subtitle: "Tu margen para familia y amigos") {
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text("Descuento al proyecto"); Spacer(); Text("\(q.descuento)%").monospacedDigit().bold() }
                Slider(value: Binding(get: { Double(q.descuento) }, set: { q.descuento = Int($0) }), in: 0...50, step: 5)
                    .tint(q.descuento > store.ajustes.piso ? .orange : .accentColor)
                MarginBar(discount: q.descuento, floor: store.ajustes.piso, listText: money(r.list), floorText: money(r.floor))
                    .padding(.top, 4)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text("Descuento mensual"); Spacer(); Text("\(q.descMo)%").monospacedDigit().bold() }
                Slider(value: Binding(get: { Double(q.descMo) }, set: { q.descMo = Int($0) }), in: 0...40, step: 5)
            }
            HStack(spacing: 6) {
                if q.descuento > store.ajustes.piso {
                    Tag(text: "\(q.descuento - store.ajustes.piso)% por debajo de tu mínimo", color: .orange)
                } else if q.descuento > 0 {
                    Tag(text: "Dentro de tu margen", color: .green)
                }
                Spacer()
            }
            Divider()
            VStack(spacing: 6) {
                if r.iva > 0 {
                    totalRow("Proyecto sin IVA", money(r.special), muted: true)
                    totalRow("IVA 13%", "+" + money(r.specialIva - r.special), muted: true)
                    totalRow("Proyecto con IVA", money(r.specialIva), bold: true)
                    totalRow("Mensual con IVA", money(r.specialMonthlyIva) + "/mes", bold: true)
                    Text("Mensual sin IVA: \(money(r.specialMonthly))").font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    totalRow("Proyecto", money(r.special), bold: true)
                    totalRow("Mensual", money(r.specialMonthly) + "/mes", bold: true)
                }
                totalRow("Adelanto 50%", money(r.deposit), muted: true)
                totalRow("Primer año", money(r.firstYear), muted: true)
                if q.mercado == "cr" {
                    totalRow("En colones (₡\(Int(store.ajustes.tipoCambio)) por $1)",
                             "≈ \(colones(r.specialIva, store.ajustes.tipoCambio)) · \(colones(r.specialMonthlyIva, store.ajustes.tipoCambio))/mes", muted: true)
                }
            }
            .font(.callout)
        }
    }
}

private func totalRow(_ label: String, _ value: String, bold: Bool = false, muted: Bool = false) -> some View {
    HStack {
        Text(label).foregroundStyle(muted ? .secondary : .primary)
        Spacer()
        Text(value).fontWeight(bold ? .bold : .regular).monospacedDigit()
    }
}

struct BulletLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon.font(.system(size: 5)).foregroundStyle(.secondary)
            configuration.title
        }
    }
}

// MARK: - Hoja de propuesta

struct ProposalSheet: View {
    let item: FormItem
    @Binding var q: Quote
    let ajustes: Ajustes
    let whatsappNumber: String?
    let onCopy: (String) -> Void
    let onSent: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var lang: String
    @State private var pdfURL: URL?

    @State private var langOk = false

    init(item: FormItem, q: Binding<Quote>, ajustes: Ajustes, whatsappNumber: String?, onCopy: @escaping (String) -> Void, onSent: (() -> Void)?) {
        self.item = item; _q = q; self.ajustes = ajustes; self.whatsappNumber = whatsappNumber
        self.onCopy = onCopy; self.onSent = onSent
        _lang = State(initialValue: item.lang == "en" ? "en" : "es")
    }

    @State private var enColones = false
    /// Avisos de idioma: la propuesta no está en el idioma del cliente, o un concepto tuyo quedó en otro idioma
    @ViewBuilder private var revisorIdioma: some View {
        let clientLang = item.lang == "en" ? "en" : "es"
        let issues = IdiomaCheck.issues(q, lang: lang)
        if (lang != clientLang && !langOk) || !issues.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Revisa el idioma", systemImage: "character.bubble.fill").font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
                if lang != clientLang && !langOk {
                    HStack(alignment: .firstTextBaseline) {
                        Text("El cliente llenó el formulario en \(IdiomaCheck.nombre(clientLang)) y la propuesta está en \(IdiomaCheck.nombre(lang)).")
                            .font(.callout)
                        Spacer()
                        Button("Cambiar") { lang = clientLang }.buttonStyle(.bordered).controlSize(.small)
                        Button("Está bien") { langOk = true }.buttonStyle(.borderless).controlSize(.small)
                    }
                }
                ForEach(issues) { i in
                    HStack(alignment: .firstTextBaseline) {
                        Text("«\(i.text)» parece estar en \(IdiomaCheck.nombre(i.detected)).").font(.callout)
                        Spacer()
                        Button("Está bien") { q.ignorarIdioma.append(i.text) }.buttonStyle(.borderless).controlSize(.small)
                    }
                }
                if !issues.isEmpty {
                    Text("Corrígelo en la pestaña Cotización → Precios, o márcalo como bien si así lo quieres.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var content: ProposalContent { Proposal.content(item, q, ajustes, lang: lang, enColones: enColones && q.mercado == "cr") }
    private var text: String { Proposal.text(content) }
    private var whatsapp: URL? {
        guard let n = whatsappNumber else { return nil }
        let t = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://wa.me/\(n)?text=\(t)")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("Idioma", selection: $lang) {
                            Text("Español").tag("es")
                            Text("English").tag("en")
                        }
                        .pickerStyle(.segmented)
                        Text(item.lang == "en" ? "El cliente llenó el formulario en inglés." : "El cliente llenó el formulario en español.")
                            .font(.caption).foregroundStyle(.secondary)
                        revisorIdioma
                        if q.mercado == "cr" {
                            Toggle("Mostrar también en colones (₡\(Int(ajustes.tipoCambio)) por $1)", isOn: $enColones)
                                .font(.callout)
                        }
                    }
                    Text(text)
                        .font(.callout)
                        .textSelection(.enabled)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(spacing: 10) {
                        if let pdf = pdfURL {
                            ShareLink(item: pdf) {
                                Label(lang == "en" ? "Compartir PDF (inglés)" : "Compartir PDF", systemImage: "doc.richtext.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                        } else {
                            ProgressView("Preparando PDF…").frame(maxWidth: .infinity)
                        }
                        if let w = whatsapp {
                            Link(destination: w) {
                                Label("Mandar por WhatsApp", systemImage: "message.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).tint(.green).controlSize(.large)
                        }
                        Button { onCopy(text) } label: { Label("Copiar texto", systemImage: "doc.on.doc").frame(maxWidth: .infinity) }
                            .buttonStyle(.bordered).controlSize(.large)
                        ShareLink(item: text) { Label("Compartir texto", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                            .buttonStyle(.bordered).controlSize(.large)
                        if let onSent {
                            Button { onSent(); dismiss() } label: {
                                Label("Ya se la mandé: pasar a «Propuesta enviada»", systemImage: "paperplane").frame(maxWidth: .infinity)
                            }
                            .controlSize(.large)
                        }
                    }
                }
                .padding()
            }
            .background(Color.pageBackground)
            .navigationTitle("Propuesta")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
            .task(id: "\(lang)\(enColones)") { pdfURL = nil; pdfURL = ProposalPDF.make(content) }
            .onAppear { enColones = q.mercado == "cr" }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }
}
