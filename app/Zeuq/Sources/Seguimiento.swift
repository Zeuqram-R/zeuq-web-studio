import SwiftUI

// MARK: - Tipos

enum Etapa {
    /// Orden del camino normal de un proyecto
    static let camino = ["procesado", "enviada", "aceptada", "construccion", "entregada"]

    static func nombre(_ e: String) -> String {
        switch e {
        case "nuevo": return "Nuevo"
        case "procesado": return "Cotizado"
        case "enviada": return "Propuesta enviada"
        case "aceptada": return "Aceptada"
        case "construccion": return "En construcción"
        case "entregada": return "Entregada"
        case "rechazada": return "Rechazada"
        case "archivado": return "Archivado"
        default: return e
        }
    }

    static func color(_ e: String) -> Color {
        switch e {
        case "nuevo": return .accentColor
        case "procesado": return .indigo
        case "enviada": return .orange
        case "aceptada": return .green
        case "construccion": return .teal
        case "entregada": return .mint
        case "rechazada": return .red
        default: return .gray
        }
    }

    static func icon(_ e: String) -> String {
        switch e {
        case "procesado": return "dollarsign.circle"
        case "enviada": return "paperplane"
        case "aceptada": return "hand.thumbsup"
        case "construccion": return "hammer"
        case "entregada": return "checkmark.seal"
        case "rechazada": return "xmark.circle"
        case "archivado": return "archivebox"
        default: return "tray"
        }
    }

    /// Grupos de la bandeja
    static let grupos: [(id: String, nombre: String, estados: [String])] = [
        ("nuevos", "Nuevos", ["nuevo"]),
        ("curso", "En curso", ["procesado", "enviada", "aceptada", "construccion"]),
        ("clientes", "Clientes", ["entregada"]),
        ("cerrados", "Cerrados", ["rechazada", "archivado"]),
    ]
}

// MARK: - Pestaña Seguimiento

/// Lo que se puede cambiar en la pestaña Seguimiento (se guarda junto con la cotización).
struct Track: Equatable {
    var notas = ""
    var pagos = Pagos()
    var horasLog: [RegistroHoras] = []

    init(_ item: FormItem) {
        notas = item.notas ?? ""
        pagos = item.pagos ?? Pagos()
        horasLog = item.horasLog ?? []
    }

    func apply(to it: inout FormItem) {
        it.notas = notas.isEmpty ? nil : notas
        it.pagos = pagos == Pagos() ? nil : pagos
        it.horasLog = horasLog.isEmpty ? nil : horasLog
    }
}

struct SeguimientoTab: View {
    @EnvironmentObject var store: Store
    let item: FormItem
    let r: PriceResult
    @Binding var track: Track
    let onEstado: (String) -> Void
    let onPersist: () -> Void

    @State private var nuevasHoras = 1.0
    @State private var notaHoras = ""
    @State private var mesHoras = Mes.key()

    private var hora: Double { store.ajustes.rates(item.quote.mercado).hora }

    var body: some View {
        VStack(spacing: 14) {
            etapa
            pagos
            horas
            notas
        }
        .padding(.top, 4)
    }

    // Etapa
    private var etapa: some View {
        Card(title: "Etapa", icon: Etapa.icon(item.estado), color: Etapa.color(item.estado),
             subtitle: Etapa.nombre(item.estado)) {
            HStack(spacing: 4) {
                ForEach(Etapa.camino, id: \.self) { e in
                    let idx = Etapa.camino.firstIndex(of: item.estado) ?? -1
                    let i = Etapa.camino.firstIndex(of: e) ?? 0
                    VStack(spacing: 4) {
                        Capsule().fill(i <= idx ? Etapa.color(item.estado) : Color.secondary.opacity(0.2)).frame(height: 6)
                        Text(Etapa.nombre(e)).font(.system(size: 10, weight: e == item.estado ? .bold : .regular))
                            .foregroundStyle(e == item.estado ? .primary : .secondary)
                            .lineLimit(2).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if item.necesitaSeguimiento, let d = item.enviadaEl {
                Label("Mandaste la propuesta hace \(Int(Date().timeIntervalSince(d) / 86400)) días. Escríbele para darle seguimiento.",
                      systemImage: "bell.badge")
                    .font(.callout).foregroundStyle(.orange)
            }
            ColumnsLayout(minWidth: 150, spacing: 8) {
                if let next = siguiente {
                    Button { onEstado(next) } label: {
                        Label(accion(next), systemImage: Etapa.icon(next)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(Etapa.color(next))
                }
                if ["procesado", "enviada"].contains(item.estado) {
                    Button(role: .destructive) { onEstado("rechazada") } label: {
                        Label("No aceptó", systemImage: "xmark.circle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                if let back = anterior {
                    Button { onEstado(back) } label: {
                        Label("Volver a \(Etapa.nombre(back).lowercased())", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            if let h = item.historial, !h.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(h.reversed()) { e in
                        HStack {
                            Circle().fill(Etapa.color(e.estado)).frame(width: 7, height: 7)
                            Text(Etapa.nombre(e.estado)).font(.caption.weight(.medium))
                            Spacer()
                            Text(shortDate(e.fecha)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var siguiente: String? {
        switch item.estado {
        case "nuevo": return "procesado"
        case "rechazada", "archivado": return "procesado"
        default:
            guard let i = Etapa.camino.firstIndex(of: item.estado), i + 1 < Etapa.camino.count else { return nil }
            return Etapa.camino[i + 1]
        }
    }

    private var anterior: String? {
        guard let i = Etapa.camino.firstIndex(of: item.estado), i > 0 else { return nil }
        return Etapa.camino[i - 1]
    }

    private func accion(_ e: String) -> String {
        switch e {
        case "procesado": return item.estado == "nuevo" ? "Marcar como cotizado" : "Reabrir cotización"
        case "enviada": return "Ya mandé la propuesta"
        case "aceptada": return "Aceptó la propuesta"
        case "construccion": return "Empecé a construir"
        case "entregada": return "Entregué la página"
        default: return Etapa.nombre(e)
        }
    }

    // Pagos
    private var pagos: some View {
        Card(title: "Pagos", icon: "banknote.fill", color: .green,
             subtitle: "Proyecto \(money(r.specialIva)) · Mensual \(money(r.specialMonthlyIva))") {
            pagoRow("Adelanto (50%)", money(r.deposit), fecha: track.pagos.adelanto) { track.pagos.adelanto = $0 ? nowISO() : nil; onPersist() }
            pagoRow("Saldo al entregar", money(r.specialIva - r.deposit), fecha: track.pagos.saldo) { track.pagos.saldo = $0 ? nowISO() : nil; onPersist() }
            Divider()
            if let inicio = track.pagos.inicioMantenimiento {
                HStack {
                    Text("Mantenimiento desde").font(.callout)
                    Spacer()
                    Button { track.pagos.inicioMantenimiento = Mes.prev(inicio); onPersist() } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.borderless)
                    Text(Mes.nombre(inicio)).font(.callout.weight(.semibold)).frame(minWidth: 120)
                    Button { track.pagos.inicioMantenimiento = Mes.next(inicio); onPersist() } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(.borderless)
                }
                let meses = Mes.range(inicio, Mes.key()).reversed()
                if meses.isEmpty {
                    Text("El primer cobro es en \(Mes.nombre(inicio)).").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(Array(meses), id: \.self) { m in
                    pagoRow(Mes.nombre(m), money(r.specialMonthlyIva), fecha: track.pagos.mensualidades[m]) { paid in
                        track.pagos.mensualidades[m] = paid ? nowISO() : nil; onPersist()
                    }
                }
                Button(role: .destructive) { track.pagos.inicioMantenimiento = nil; onPersist() } label: {
                    Label("Quitar mantenimiento", systemImage: "minus.circle")
                }
                .font(.caption)
            } else {
                Button { track.pagos.inicioMantenimiento = Mes.key(); onPersist() } label: {
                    Label("Empezar a cobrar mantenimiento", systemImage: "calendar.badge.plus")
                }
                Text("Llevas el control de cada mensualidad: quién pagó y quién está atrasado.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func pagoRow(_ label: String, _ amount: String, fecha: String?, toggle: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: 10) {
            Button { toggle(fecha == nil) } label: {
                Image(systemName: fecha != nil ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(fecha != nil ? Color.green : .secondary)
            }
            .buttonStyle(.borderless)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.callout)
                Text(fecha != nil ? "Pagado el \(shortDate(fecha))" : "Pendiente").font(.caption)
                    .foregroundStyle(fecha != nil ? Color.green : .orange)
            }
            Spacer()
            Text(amount).font(.callout.weight(.semibold)).monospacedDigit()
        }
    }

    // Horas
    private var horas: some View {
        let incl = item.horasIncluidas
        let usadas = track.horasLog.filter { $0.mes == mesHoras }.reduce(0) { $0 + $1.horas }
        let extra = max(0, usadas - incl)
        return Card(title: "Horas de mantenimiento", icon: "clock.fill", color: .gray,
                    subtitle: "Incluidas: \(fmtH(incl)) al mes · Hora extra \(money(hora))") {
            HStack {
                Button { mesHoras = Mes.prev(mesHoras) } label: { Image(systemName: "chevron.left") }.buttonStyle(.borderless)
                Text(Mes.nombre(mesHoras)).font(.callout.weight(.semibold)).frame(maxWidth: .infinity)
                Button { mesHoras = Mes.next(mesHoras) } label: { Image(systemName: "chevron.right") }.buttonStyle(.borderless)
                    .disabled(mesHoras >= Mes.key())
            }
            ProgressView(value: min(usadas, max(incl, usadas)), total: max(incl, usadas, 0.01))
                .tint(extra > 0 ? .orange : .accentColor)
            HStack {
                Text("Usadas: \(fmtH(usadas)) de \(fmtH(incl))").font(.callout)
                Spacer()
                if extra > 0 {
                    Tag(text: "\(fmtH(extra)) extra · cobrar \(money(extra * hora))", color: .orange)
                }
            }
            ForEach(track.horasLog.filter { $0.mes == mesHoras }.sorted { $0.fecha > $1.fecha }) { h in
                HStack {
                    Text(shortDate(h.fecha)).font(.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                    Text(h.nota.isEmpty ? "Cambios" : h.nota).font(.callout)
                    Spacer()
                    Text(fmtH(h.horas)).font(.callout.weight(.semibold)).monospacedDigit()
                    Button(role: .destructive) { track.horasLog.removeAll { $0.id == h.id }; onPersist() } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                }
            }
            if mesHoras == Mes.key() {
                Divider()
                HStack {
                    TextField("¿Qué cambiaste?", text: $notaHoras)
                    Stepper(fmtH(nuevasHoras), value: $nuevasHoras, in: 0.25...12, step: 0.25).fixedSize()
                }
                Button {
                    track.horasLog.append(RegistroHoras(fecha: nowISO(), horas: nuevasHoras, nota: notaHoras))
                    notaHoras = ""; nuevasHoras = 1
                    onPersist()
                } label: { Label("Anotar horas", systemImage: "plus.circle.fill") }
            }
        }
    }

    private func fmtH(_ h: Double) -> String {
        let v = (h * 100).rounded() / 100
        return (v == v.rounded() ? String(Int(v)) : String(format: "%g", v)) + " h"
    }

    // Notas
    private var notas: some View {
        Card(title: "Notas internas", icon: "note.text", color: .yellow, subtitle: "Solo las ves tú. Se guardan con «Guardar».") {
            TextEditor(text: $track.notas)
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Resumen del negocio

struct ResumenView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private var mes: String { Mes.key() }
    private func price(_ it: FormItem) -> PriceResult { Pricing.compute(it.quote, store.ajustes) }
    private var activos: [FormItem] {
        store.items.filter { $0.estado == "entregada" && $0.pagos?.inicioMantenimiento != nil }
    }
    private var fijo: Double { activos.reduce(0) { $0 + price($1).specialMonthlyIva } }
    private var pendientesMes: [FormItem] { store.items.filter { $0.mensualidadPendiente(mes) } }
    private var porCobrar: [(FormItem, String, Double)] {
        var out: [(FormItem, String, Double)] = []
        for it in store.items where ["aceptada", "construccion", "entregada"].contains(it.estado) {
            let r = price(it)
            if it.pagos?.adelanto == nil { out.append((it, "Adelanto", r.deposit)) }
            if it.estado == "entregada", it.pagos?.saldo == nil { out.append((it, "Saldo", r.specialIva - r.deposit)) }
        }
        return out
    }
    private var extras: [(FormItem, Double)] {
        store.items.compactMap { it in
            let e = max(0, it.horasUsadas(mes) - it.horasIncluidas)
            return e > 0 ? (it, e * store.ajustes.rates(it.quote.mercado).hora) : nil
        }
    }
    private var seguimiento: [FormItem] { store.items.filter(\.necesitaSeguimiento) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ingreso mensual fijo").font(.subheadline).foregroundStyle(.secondary)
                        Text(money(fijo)).font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                        Text("\(activos.count) cliente\(activos.count == 1 ? "" : "s") con mantenimiento").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    lista("Mensualidades pendientes de \(Mes.nombre(mes))", icon: "calendar.badge.exclamationmark", color: .orange,
                          rows: pendientesMes.map { ($0.titulo, money(price($0).specialMonthlyIva)) },
                          empty: "Todos te pagaron este mes.")
                    lista("Por cobrar de proyectos", icon: "banknote", color: .green,
                          rows: porCobrar.map { ("\($0.0.titulo) · \($0.1)", money($0.2)) },
                          empty: "No tienes adelantos ni saldos pendientes.")
                    lista("Horas extra a cobrar este mes", icon: "clock.badge.exclamationmark", color: .gray,
                          rows: extras.map { ($0.0.titulo, money($0.1)) },
                          empty: "Nadie se pasó de sus horas este mes.")
                    lista("Propuestas sin respuesta (3 días o más)", icon: "bell.badge", color: .orange,
                          rows: seguimiento.map { ($0.titulo, shortDate($0.historial?.last(where: { $0.estado == "enviada" })?.fecha)) },
                          empty: "No hay propuestas esperando respuesta.")
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color.pageBackground)
            .navigationTitle("Resumen")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
        #endif
    }

    private func lista(_ title: String, icon: String, color: Color, rows: [(String, String)], empty: String) -> some View {
        Card(title: title, icon: icon, color: color) {
            if rows.isEmpty {
                Text(empty).font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                    HStack { Text(r.0).font(.callout); Spacer(); Text(r.1).font(.callout.weight(.semibold)).monospacedDigit() }
                }
            }
        }
    }
}
