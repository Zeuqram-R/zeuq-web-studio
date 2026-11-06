import SwiftUI
import AppKit

// Genera capturas de las pestañas para revisar el diseño (datos de ejemplo, no de clientes).
@main
struct Render {
    @MainActor static func main() {
        let data: [String: JSONValue] = [
            "nombre": .string("Juan Ejemplo"), "negocio": .string("JE Fitness"), "rubro": .string("Entrenador personal"),
            "email": .string("juan@ejemplo.com"), "whatsapp": .string("+1 561 000 0000"), "presupuesto": .string("1000-2500"),
            "objetivo": .array([.string("agendar"), .string("contenido"), .string("clientes")]), "sitio_actual": .string("no"),
            "diseno": .string("semi"), "paginas": .array([.string("testimonios"), .string("precios")]), "reservas": .string("cobrar"),
            "modalidad": .string("ambas"), "tienda": .string("no"), "membresia": .string("nose"), "formulario": .string("si"),
            "extras": .array([.string("newsletter"), .string("seo")]), "blog": .string("completo"), "autor": .string("el"),
            "articulos": .number(5), "videos": .string("insertados"), "logo": .string("si"), "fotos": .string("banco"),
            "textos": .string("el"), "dominio": .string("no"), "idioma": .string("bi"), "plazo": .string("normal"),
            "horas": .string("3"), "artmes": .string("2"), "reporte": .string("no"),
            "comentarios": .string("Quiere material de salud, alimentación y ejercicio."),
        ]
        var item = FormItem(id: "x", fecha: "2026-11-05T23:37:06Z", lang: "es", estado: "nuevo", confirmado: "sí", data: data, cotizacion: nil)
        var q = item.quote
        q.descuento = 15
        q.overrides = ["base": 800]
        q.custom = [CustomLine(text: "Migrar contenido de Instagram", amount: 150)]
        item.cotizacion = q
        let store = Store.shared
        let r = Pricing.compute(q, store.ajustes)
        var seg = item
        seg.estado = "entregada"
        seg.historial = [Evento(estado: "procesado", fecha: "2026-10-20T15:00:00Z"), Evento(estado: "enviada", fecha: "2026-10-21T15:00:00Z"),
                         Evento(estado: "aceptada", fecha: "2026-10-24T15:00:00Z"), Evento(estado: "entregada", fecha: "2026-11-02T15:00:00Z")]
        seg.pagos = Pagos(adelanto: "2026-10-24T15:00:00Z", saldo: nil, inicioMantenimiento: "2026-10", mensualidades: ["2026-10": "2026-10-30T15:00:00Z"])
        seg.horasLog = [RegistroHoras(fecha: nowISO(), horas: 2.5, nota: "Cambié precios"), RegistroHoras(fecha: nowISO(), horas: 1.5, nota: "Fotos nuevas")]
        seg.notas = "Prefiere colores oscuros. Paga por Zelle."
        shot(SeguimientoTab(item: seg, r: r, track: .constant(Track(seg)), onEstado: { _ in }, onPersist: {}), "seguimiento-light.png", false, store)
        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            shot(ClienteTab(item: item), "cliente-\(suffix).png", dark, store)
            shot(CotizacionTab(item: item, q: .constant(q), r: r), "cotizacion-\(suffix).png", dark, store)
        }
        shot(List { FormRow(item: item); FormRow(item: item) }.frame(height: 220), "lista-light.png", false, store)
        for lang in ["es", "en"] {
            let c = Proposal.content(item, q, store.ajustes, lang: lang)
            let r = ImageRenderer(content: ProposalDocument(c: c))
            r.scale = 1.5
            if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: "capturas/pdf-\(lang).png"))
                print("captura pdf-\(lang).png \(Int(img.size.width))x\(Int(img.size.height))")
            }
            if let u = ProposalPDF.make(c) {
                try? FileManager.default.removeItem(atPath: "capturas/propuesta-\(lang).pdf")
                try? FileManager.default.copyItem(atPath: u.path, toPath: "capturas/propuesta-\(lang).pdf")
                print("pdf listo \(lang)")
            }
        }
    }

    @MainActor static func shot<V: View>(_ v: V, _ name: String, _ dark: Bool, _ store: Store) {
        let content = v
            .padding()
            .frame(width: 760)
            .background(Color.pageBackground)
            .environmentObject(store)
            .environment(\.colorScheme, dark ? .dark : .light)
        let r = ImageRenderer(content: content)
        r.scale = 1
        guard let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { print("sin imagen \(name)"); return }
        try? png.write(to: URL(fileURLWithPath: "capturas/" + name))
        print("captura \(name) \(Int(img.size.width))x\(Int(img.size.height))")
    }
}
