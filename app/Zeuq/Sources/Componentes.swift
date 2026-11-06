import SwiftUI

extension Color {
    /// Fondo de la página y de las tarjetas, según el sistema
    static var pageBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
    static var cardBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
}

/// Tarjeta con título e ícono de color, para separar cada sección.
struct Card<Content: View>: View {
    let title: String
    let icon: String
    var color: Color = .accentColor
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.headline)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Fila "etiqueta: valor" para las respuestas del cliente.
struct InfoRow: View {
    let label: String
    let value: String
    var muted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.body).foregroundStyle(muted ? .secondary : .primary).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Opciones tocables como en la página (una sola o varias).
struct OptionGrid: View {
    let question: Question
    @Binding var q: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.label).font(.subheadline.weight(.semibold))
            if let h = question.help { Text(h).font(.caption).foregroundStyle(.secondary) }
            ColumnsLayout(minWidth: 150, spacing: 8) {
                ForEach(question.opts) { o in
                    let selected = question.multi ? Pricing.list(q, question.id).contains(o.v) : Pricing.value(q, question.id) == o.v
                    Button {
                        if question.multi { Pricing.toggle(&q, question.id, o.v, !selected) }
                        else { Pricing.setValue(&q, question.id, o.v) }
                    } label: {
                        HStack(alignment: .top, spacing: 6) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(o.t).font(.subheadline.weight(.medium)).multilineTextAlignment(.leading)
                                let c = Pricing.chip(o, mercado: q.mercado)
                                if !c.isEmpty {
                                    Text(c).font(.caption.weight(.semibold)).monospacedDigit()
                                        .foregroundStyle(selected ? Color.accentColor : .secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            if question.multi {
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: .infinity, alignment: .topLeading)
                        .background(selected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Columnas de ancho igual que se acomodan al ancho disponible. No es "lazy": así la página
/// no salta de lugar cuando cambia algo (con LazyVGrid la vista se movía al primer cambio).
struct ColumnsLayout: Layout {
    var minWidth: CGFloat = 150
    var spacing: CGFloat = 8

    private func columns(_ width: CGFloat) -> Int { max(1, Int((width + spacing) / (minWidth + spacing))) }

    private func rows(_ width: CGFloat, _ subviews: Subviews) -> (n: Int, cw: CGFloat, heights: [CGFloat]) {
        let n = columns(width)
        let cw = max(0, (width - CGFloat(n - 1) * spacing) / CGFloat(n))
        var heights: [CGFloat] = []
        var i = 0
        while i < subviews.count {
            let end = min(i + n, subviews.count)
            heights.append((i..<end).map { subviews[$0].sizeThatFits(ProposedViewSize(width: cw, height: nil)).height }.max() ?? 0)
            i = end
        }
        return (n, cw, heights)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? (minWidth * 2 + spacing)
        let r = rows(width, subviews)
        let h = r.heights.reduce(0, +) + spacing * CGFloat(max(0, r.heights.count - 1))
        return CGSize(width: width, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = rows(bounds.width, subviews)
        var y = bounds.minY
        for (row, h) in r.heights.enumerated() {
            for col in 0..<r.n {
                let i = row * r.n + col
                guard i < subviews.count else { break }
                let x = bounds.minX + CGFloat(col) * (r.cw + spacing)
                subviews[i].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: r.cw, height: h))
            }
            y += h + spacing
        }
    }
}

/// Campo de monto en dólares. Guarda el valor al terminar de escribir (Listo, Enter o tocar fuera),
/// así el teclado no se cierra con cada dígito.
struct AmountField: View {
    @Binding var value: Double
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 2) {
            Text("$").foregroundStyle(.secondary)
            TextField("0", text: $text)
                .focused($focused)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 80)
                .onSubmit(commit)
                .onAppear { text = Self.format(value) }
                .onChange(of: focused) { _, f in if !f { commit() } }
                .onChange(of: value) { _, v in if !focused { text = Self.format(v) } }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(focused ? 0.18 : 0.1), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(focused ? Color.accentColor : .clear))
    }

    private func commit() {
        let clean = text.filter { $0.isNumber || $0 == "." }
        if let v = Double(clean) { if v != value { value = v } } else { text = Self.format(value) }
    }

    static func format(_ v: Double) -> String { String(Int(v.rounded())) }
}

/// Barra visual del margen de descuento: la franja azul es lo que te puedes permitir,
/// la rayita es el descuento que estás dando.
struct MarginBar: View {
    let discount: Int
    let floor: Int
    let listText: String
    let floorText: String
    private let maxValue = 50.0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { g in
                let w = g.size.width
                let over = discount > floor
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.18)).frame(height: 10)
                    Capsule().fill(Color.accentColor.opacity(0.6)).frame(width: w * min(1, Double(floor) / maxValue), height: 10)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(over ? Color.orange : Color.primary)
                        .frame(width: 4, height: 22)
                        .offset(x: min(w - 4, max(0, w * Double(discount) / maxValue - 2)))
                }
                .frame(height: 22)
            }
            .frame(height: 22)
            HStack {
                Text("0% · Lista \(listText)")
                Spacer()
                Text("Tu mínimo \(floorText) (−\(floor)%)").foregroundStyle(Color.accentColor)
                Spacer()
                Text("−50%")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .animation(.easeOut(duration: 0.15), value: discount)
    }
}

/// Íconos y colores de cada sección del cotizador.
enum SectionStyle {
    static func icon(_ title: String) -> String {
        switch title {
        case "Diseño y páginas": return "paintbrush.pointed.fill"
        case "Funciones": return "calendar.badge.clock"
        case "Contenido": return "doc.richtext.fill"
        case "Marca y materiales": return "photo.on.rectangle.angled"
        case "Idioma y plazo": return "globe"
        case "Mantenimiento": return "wrench.and.screwdriver.fill"
        default: return "square.grid.2x2.fill"
        }
    }
    static func color(_ title: String) -> Color {
        switch title {
        case "Diseño y páginas": return .pink
        case "Funciones": return .orange
        case "Contenido": return .teal
        case "Marca y materiales": return .purple
        case "Idioma y plazo": return .indigo
        case "Mantenimiento": return .gray
        default: return .accentColor
        }
    }
}
