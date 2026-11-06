import SwiftUI

/// Primera vez: pegar el token de GitHub.
struct SetupView: View {
    @EnvironmentObject var store: Store
    @State private var token = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Zeuq Web Studio").font(.largeTitle.weight(.bold))
                        Text("Para ver los formularios de tus clientes, conecta la app con tu repo privado zeuq-confirmaciones usando un token de GitHub.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                Section {
                    SecureField("github_pat_…", text: $token)
                        .textContentType(.password)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                    Button(busy ? "Revisando…" : "Conectar") {
                        busy = true
                        Task { error = await store.saveToken(token); busy = false }
                    }
                    .disabled(busy || token.isEmpty)
                } header: {
                    Text("Token de GitHub")
                } footer: {
                    Text("Se guarda solo en el Llavero de este dispositivo.")
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Conectar")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var aj = Ajustes()
    @State private var saving = false
    @State private var note: String?
    @AppStorage(Bloqueo.key) private var bloqueo = false

    var body: some View {
        NavigationStack {
            Form {
                rates("Florida / EE. UU.", $aj.fl)
                rates("Costa Rica", $aj.cr)
                Section {
                    Toggle("Actualizar solo (BCCR, dos veces al día)", isOn: $aj.tipoCambioAuto)
                    if aj.tipoCambioAuto {
                        if let tc = store.tipoCambio {
                            LabeledContent("Venta", value: "₡" + String(format: "%.2f", tc.venta))
                            LabeledContent("Compra", value: "₡" + String(format: "%.2f", tc.compra))
                            LabeledContent("Fecha", value: tc.fecha)
                        } else {
                            Text("Todavía no hay dato del BCCR. Mientras tanto se usa ₡\(String(format: "%.2f", aj.tipoCambio)).")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    } else {
                        LabeledContent("Colones por $1") {
                            TextField("460", value: $aj.tipoCambio, format: .number)
                                .multilineTextAlignment(.trailing)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .frame(maxWidth: 120)
                        }
                    }
                } header: {
                    Text("Tipo de cambio")
                } footer: {
                    Text(aj.tipoCambioAuto ? "Se usa el tipo de cambio de venta de referencia del BCCR, el mismo de tu app de gastos." :
                         "Pusiste el tipo de cambio a mano. Actívalo de nuevo para que se actualice solo.")
                }
                Section {
                    NavigationLink { PreciosView(aj: $aj) } label: {
                        Label("Precios de cada opción", systemImage: "tag")
                    }
                } footer: {
                    Text("Cambia lo que cobras por cada opción, en Florida y en Costa Rica.")
                }
                Section {
                    Stepper("Descuento máximo: \(aj.piso)%", value: $aj.piso, in: 0...50, step: 5)
                } footer: {
                    Text("Hasta dónde puedes bajar el precio para amigos y familia sin perder.")
                }
                Section {
                    Button(saving ? "Guardando…" : "Guardar tarifas") {
                        saving = true
                        Task {
                            note = await store.saveAjustes(aj) ? "Tarifas guardadas en todos tus dispositivos." : store.message
                            saving = false
                        }
                    }
                    .disabled(saving || aj == store.ajustes)
                    if let note { Text(note).font(.footnote).foregroundStyle(.secondary) }
                }
                Section {
                    Toggle("Pedir \(Bloqueo.nombre) al abrir", isOn: Binding(get: { bloqueo }, set: { on in
                        Task { if await Bloqueo.verificar(on ? "Activar el bloqueo de Zeuq" : "Quitar el bloqueo de Zeuq") { bloqueo = on } }
                    }))
                } header: {
                    Text("Seguridad")
                } footer: {
                    Text("La app se bloquea cada vez que la cierras o cambias a otra app.")
                }
                Section("Avisos") {
                    Button("Permitir notificaciones") { Store.requestNotifications() }
                    Text("La app revisa cada 5 minutos mientras está abierta. En el iPhone y el iPad también revisa en segundo plano cuando iOS lo permite, que puede tardar. Para enterarte al instante, sigue usando Telegram.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Cuenta") {
                    if let d = store.lastSync {
                        LabeledContent("Última actualización", value: d.formatted(date: .abbreviated, time: .shortened))
                    }
                    Button("Quitar token de GitHub", role: .destructive) { store.removeToken(); dismiss() }
                }
                Section {
                    LabeledContent("Versión", value: version)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Ajustes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
            }
            .onAppear { aj = store.ajustes }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
    }

    private func rates(_ title: String, _ r: Binding<MarketRates>) -> some View {
        Section(title) {
            field("Sitio base", r.base)
            field("Mantenimiento base /mes", r.mensual)
            field("Hora extra", r.hora)
        }
    }

    private func field(_ label: String, _ v: Binding<Double>) -> some View {
        LabeledContent(label) {
            TextField(label, value: v, format: .number)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .frame(maxWidth: 120)
        }
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}


/// Lista de todas las opciones con su precio en el mercado elegido. Se guarda con «Guardar tarifas».
struct PreciosView: View {
    @Binding var aj: Ajustes
    @State private var mercado = "fl"

    private func binding(_ key: String, _ def: Double) -> Binding<Double> {
        Binding(get: { aj.precio(mercado, key) ?? def },
                set: { v in
                    if v == def { aj.precios[mercado]?[key] = nil } else { aj.precios[mercado, default: [:]][key] = v }
                })
    }

    var body: some View {
        Form {
            Section {
                Picker("Mercado", selection: $mercado) {
                    Text("Florida / EE. UU.").tag("fl")
                    Text("Costa Rica").tag("cr")
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Los cambios se guardan cuando vuelves y tocas «Guardar tarifas».")
            }
            ForEach(Catalog.sections) { s in
                Section(s.title) {
                    ForEach(s.questions) { q in
                        ForEach(q.opts.filter { $0.p > 0 }) { o in
                            row("\(q.label): \(o.t)", key: "\(q.id).\(o.v)", opt: o)
                        }
                    }
                }
            }
            Section("Otros cobros mensuales") {
                ForEach(Pricing.otrosCobros, id: \.key) { c in
                    let def = Pricing.round(c.base * Catalog.factor(mercado), to: 5)
                    priceRow(c.label, key: c.key, def: def, pct: false)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Precios de opciones")
    }

    @ViewBuilder private func row(_ label: String, key: String, opt o: Opt) -> some View {
        if o.k == .pct {
            priceRow(label, key: key, def: o.p, pct: true)
        } else {
            priceRow(label + (o.k == .unit ? " (c/u)" : o.k == .mo ? " (al mes)" : ""), key: key,
                     def: Pricing.round(o.p * Catalog.factor(mercado), to: 5), pct: false)
        }
    }

    private func priceRow(_ label: String, key: String, def: Double, pct: Bool) -> some View {
        let changed = aj.precio(mercado, key) != nil
        return HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.callout)
                if changed {
                    Text("Original: " + (pct ? "\(Int(def))%" : money(def))).font(.caption).foregroundStyle(.purple)
                }
            }
            Spacer()
            if pct {
                HStack(spacing: 2) {
                    TextField("0", value: binding(key, def), format: .number).multilineTextAlignment(.trailing).frame(width: 50)
                    Text("%").foregroundStyle(.secondary)
                }
            } else {
                AmountField(value: binding(key, def))
            }
            if changed {
                Button { aj.precios[mercado]?[key] = nil } label: { Image(systemName: "arrow.uturn.backward.circle") }
                    .buttonStyle(.borderless)
            }
        }
    }
}
