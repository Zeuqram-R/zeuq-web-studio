import Foundation

/// Catálogo de opciones y cálculo del precio. Es el mismo cálculo del cotizador web.
enum Kind { case fixed, pct, unit, mo, none }

struct Opt: Identifiable, Hashable {
    let v: String
    let t: String
    let p: Double
    var k: Kind = .fixed
    var id: String { v }
}

struct Question: Identifiable {
    let id: String
    let label: String
    var help: String? = nil
    var multi = false
    let opts: [Opt]
}

struct CatalogSection: Identifiable {
    let title: String
    let questions: [Question]
    var id: String { title }
}

enum Catalog {
    /// Factor de cada mercado sobre los precios de referencia de cada opción (tarifas de freelancer principiante).
    static func factor(_ mercado: String) -> Double { mercado == "cr" ? 0.4 : 0.75 }

    static let sections: [CatalogSection] = [
        CatalogSection(title: "Diseño y páginas", questions: [
            Question(id: "diseno", label: "Nivel de diseño", help: "La base incluye Inicio, Sobre mí, Servicios y Contacto, adaptable a celular.", opts: [
                Opt(v: "plantilla", t: "Sencillo con sus colores", p: 0), Opt(v: "semi", t: "Con detalles de su marca", p: 500),
                Opt(v: "medida", t: "Único, desde cero", p: 1200)]),
            Question(id: "paginas", label: "Páginas extra", multi: true, opts: [
                Opt(v: "testimonios", t: "Testimonios", p: 150), Opt(v: "portafolio", t: "Portafolio", p: 200),
                Opt(v: "galeria", t: "Galería", p: 150), Opt(v: "faq", t: "Preguntas frecuentes", p: 100),
                Opt(v: "precios", t: "Precios y paquetes", p: 100), Opt(v: "equipo", t: "Equipo", p: 100)]),
        ]),
        CatalogSection(title: "Funciones", questions: [
            Question(id: "reservas", label: "Reservas", opts: [
                Opt(v: "no", t: "No", p: 0), Opt(v: "agendar", t: "Solo agendar", p: 250),
                Opt(v: "cobrar", t: "Agendar y cobrar", p: 450), Opt(v: "paquetes", t: "Paquetes de citas", p: 650)]),
            Question(id: "modalidad", label: "Modalidad de las citas", opts: [
                Opt(v: "presencial", t: "Presenciales", p: 0), Opt(v: "online", t: "En línea", p: 100), Opt(v: "ambas", t: "Ambas", p: 150)]),
            Question(id: "tienda", label: "Tienda", opts: [
                Opt(v: "no", t: "No", p: 0), Opt(v: "pocos", t: "Hasta 10 productos", p: 600),
                Opt(v: "completa", t: "Tienda completa", p: 1500), Opt(v: "digitales", t: "Productos digitales", p: 600)]),
            Question(id: "membresia", label: "Membresía", help: "Si dijo «tal vez más adelante», no se cobra ahora: ofrécela como fase 2.", opts: [
                Opt(v: "no", t: "No", p: 0), Opt(v: "nose", t: "Más adelante", p: 0), Opt(v: "si", t: "Sí", p: 1500)]),
            Question(id: "formulario", label: "Formulario especial", opts: [Opt(v: "no", t: "Solo contacto", p: 0), Opt(v: "si", t: "Sí", p: 250)]),
            Question(id: "extras", label: "Extras", multi: true, opts: [
                Opt(v: "newsletter", t: "Newsletter", p: 200), Opt(v: "instagram", t: "Feed de Instagram", p: 100),
                Opt(v: "seo", t: "SEO básico", p: 300), Opt(v: "google", t: "Google Business", p: 150),
                Opt(v: "calculadora", t: "Calculadora / herramienta", p: 300)]),
        ]),
        CatalogSection(title: "Contenido", questions: [
            Question(id: "blog", label: "Blog", opts: [Opt(v: "no", t: "No", p: 0), Opt(v: "simple", t: "Sencillo", p: 400), Opt(v: "completo", t: "Con categorías y buscador", p: 650)]),
            Question(id: "autor", label: "Quién escribe los artículos", opts: [
                Opt(v: "el", t: "El cliente; yo subo y doy formato", p: 40, k: .unit), Opt(v: "yo", t: "Yo los redacto", p: 120, k: .unit)]),
            Question(id: "videos", label: "Videos", opts: [Opt(v: "no", t: "No", p: 0), Opt(v: "insertados", t: "Insertados", p: 0), Opt(v: "biblioteca", t: "Biblioteca organizada", p: 350)]),
        ]),
        CatalogSection(title: "Marca y materiales", questions: [
            Question(id: "logo", label: "Logo", opts: [Opt(v: "si", t: "Ya tiene", p: 0), Opt(v: "no", t: "Logo sencillo", p: 300)]),
            Question(id: "fotos", label: "Fotos", opts: [Opt(v: "si", t: "Ya tiene", p: 0), Opt(v: "banco", t: "Fotos de banco", p: 100), Opt(v: "sesion", t: "Sesión aparte", p: 0)]),
            Question(id: "textos", label: "Textos de las páginas", opts: [Opt(v: "el", t: "Los manda el cliente", p: 0), Opt(v: "yo", t: "Yo los redacto", p: 300)]),
            Question(id: "dominio", label: "Dominio", help: "Si no sabe qué es, explícale y ayúdale a comprarlo; lo paga él.", opts: [
                Opt(v: "si", t: "Ya tiene", p: 0), Opt(v: "no", t: "Hay que comprarlo", p: 0), Opt(v: "nose", t: "No sabe qué es", p: 0)]),
        ]),
        CatalogSection(title: "Idioma y plazo", questions: [
            Question(id: "idioma", label: "Idioma", opts: [Opt(v: "en", t: "Inglés", p: 0), Opt(v: "es", t: "Español", p: 0), Opt(v: "bi", t: "Bilingüe", p: 25, k: .pct)]),
            Question(id: "plazo", label: "Plazo", opts: [Opt(v: "flexible", t: "Sin prisa", p: 0), Opt(v: "normal", t: "1 o 2 meses", p: 0), Opt(v: "urgente", t: "Urgente", p: 20, k: .pct)]),
        ]),
        CatalogSection(title: "Mantenimiento", questions: [
            Question(id: "horas", label: "Cambios al mes", help: "Base: hosting, seguridad, SSL, respaldos y actualizaciones.", opts: [
                Opt(v: "1", t: "Pocos (1 h)", p: 0, k: .mo), Opt(v: "3", t: "Semanales (3 h)", p: 75, k: .mo), Opt(v: "5", t: "Frecuentes (5 h)", p: 150, k: .mo)]),
            Question(id: "artmes", label: "Artículos nuevos al mes", opts: [Opt(v: "0", t: "Ninguno", p: 0), Opt(v: "2", t: "2", p: 0), Opt(v: "4", t: "4", p: 0)]),
            Question(id: "reporte", label: "Reporte de visitas", opts: [Opt(v: "no", t: "No", p: 0), Opt(v: "si", t: "Sí", p: 30, k: .mo)]),
        ]),
    ]

    static func question(_ id: String) -> Question? {
        for s in sections { if let q = s.questions.first(where: { $0.id == id }) { return q } }
        return nil
    }

    static func opt(_ id: String, _ v: String) -> Opt {
        let q = question(id)!
        return q.opts.first(where: { $0.v == v }) ?? q.opts[0]
    }
}

struct PriceLine: Identifiable {
    let id = UUID()
    let group: String
    let text: String
    let amount: Double
}

struct PriceResult {
    var lines: [PriceLine] = []
    var subtotal: Double = 0
    var adjustments: [PriceLine] = []
    var list: Double = 0
    var monthlyLines: [PriceLine] = []
    var monthly: Double = 0
    var special: Double = 0
    var floor: Double = 0
    var specialMonthly: Double = 0
    var iva: Double = 0
    var specialIva: Double { (special * (1 + iva)).rounded() }
    var specialMonthlyIva: Double { (specialMonthly * (1 + iva)).rounded() }
    var deposit: Double { specialIva / 2 }
    var firstYear: Double { specialIva + 12 * specialMonthlyIva }
}

enum Pricing {
    static func round(_ n: Double, to step: Double) -> Double { (n / step).rounded() * step }

    static func value(_ q: Quote, _ id: String) -> String {
        switch id {
        case "diseno": return q.diseno
        case "reservas": return q.reservas
        case "modalidad": return q.modalidad
        case "tienda": return q.tienda
        case "membresia": return q.membresia
        case "formulario": return q.formulario
        case "blog": return q.blog
        case "autor": return q.autor
        case "videos": return q.videos
        case "logo": return q.logo
        case "fotos": return q.fotos
        case "textos": return q.textos
        case "dominio": return q.dominio
        case "idioma": return q.idioma
        case "plazo": return q.plazo
        case "horas": return q.horas
        case "artmes": return q.artmes
        case "reporte": return q.reporte
        default: return ""
        }
    }

    static func setValue(_ q: inout Quote, _ id: String, _ v: String) {
        switch id {
        case "diseno": q.diseno = v
        case "reservas": q.reservas = v
        case "modalidad": q.modalidad = v
        case "tienda": q.tienda = v
        case "membresia": q.membresia = v
        case "formulario": q.formulario = v
        case "blog": q.blog = v
        case "autor": q.autor = v
        case "videos": q.videos = v
        case "logo": q.logo = v
        case "fotos": q.fotos = v
        case "textos": q.textos = v
        case "dominio": q.dominio = v
        case "idioma": q.idioma = v
        case "plazo": q.plazo = v
        case "horas": q.horas = v
        case "artmes": q.artmes = v
        case "reporte": q.reporte = v
        default: break
        }
    }

    static func list(_ q: Quote, _ id: String) -> [String] { id == "paginas" ? q.paginas : q.extras }

    static func toggle(_ q: inout Quote, _ id: String, _ v: String, _ on: Bool) {
        var a = list(q, id)
        if on { if !a.contains(v) { a.append(v) } } else { a.removeAll { $0 == v } }
        if id == "paginas" { q.paginas = a } else { q.extras = a }
    }

    /// Texto del precio de una opción, ya ajustado al mercado.
    static func chip(_ o: Opt, mercado: String) -> String {
        let f = Catalog.factor(mercado)
        let px = round(o.p * f, to: 5)
        switch o.k {
        case .none: return ""
        case .pct: return "+\(Int(o.p))%"
        case .unit: return "\(money(px)) c/u"
        case .mo: return o.p > 0 ? "+\(money(px))/mes" : "Incluido"
        case .fixed: return o.p > 0 ? "+\(money(px))" : "Incluido"
        }
    }

    static func compute(_ q: Quote, _ aj: Ajustes) -> PriceResult {
        let f = Catalog.factor(q.mercado)
        let rates = aj.rates(q.mercado)
        func px(_ n: Double) -> Double { round(n * f, to: 5) }
        var r = PriceResult()
        func add(_ g: String, _ t: String, _ a: Double) { r.lines.append(PriceLine(group: g, text: t, amount: a)); r.subtotal += a }

        add("Proyecto", "Sitio base (4 páginas)", rates.base)
        let d = Catalog.opt("diseno", q.diseno)
        if d.p > 0 { add("Proyecto", "Diseño: " + d.t.lowercased(), px(d.p)) }
        for v in q.paginas { let o = Catalog.opt("paginas", v); add("Proyecto", "Página: " + o.t, px(o.p)) }
        if q.reservas != "no" {
            let o = Catalog.opt("reservas", q.reservas)
            add("Funciones", "Reservas: " + o.t.lowercased(), px(o.p))
            let m = Catalog.opt("modalidad", q.modalidad)
            if m.p > 0 { add("Funciones", "Citas " + m.t.lowercased(), px(m.p)) }
        }
        if q.tienda != "no" { let o = Catalog.opt("tienda", q.tienda); add("Funciones", "Tienda: " + o.t.lowercased(), px(o.p)) }
        if q.membresia == "si" { add("Funciones", "Membresía", px(1500)) }
        if q.formulario == "si" { add("Funciones", "Formulario especial", px(250)) }
        for v in q.extras { let o = Catalog.opt("extras", v); add("Funciones", o.t, px(o.p)) }
        let blog = q.blog != "no"
        if blog {
            let o = Catalog.opt("blog", q.blog)
            add("Contenido", "Blog " + o.t.lowercased(), px(o.p))
            let u = px(Catalog.opt("autor", q.autor).p)
            let n = q.articulos
            if n > 0 { add("Contenido", "\(n) artículo\(n > 1 ? "s" : "") iniciales (\(money(u)) c/u)", Double(n) * u) }
        }
        if q.videos == "biblioteca" { add("Contenido", "Biblioteca de videos", px(350)) }
        if q.logo == "no" { add("Marca", "Logo sencillo", px(300)) }
        if q.fotos == "banco" { add("Marca", "Fotos de banco", px(100)) }
        if q.textos == "yo" { add("Marca", "Redacción de textos", px(300)) }

        var list = r.subtotal
        if q.idioma == "bi" { let a = r.subtotal * 0.25; r.adjustments.append(PriceLine(group: "Ajustes", text: "Bilingüe (+25%)", amount: a)); list += a }
        if q.plazo == "urgente" { let a = r.subtotal * 0.2; r.adjustments.append(PriceLine(group: "Ajustes", text: "Urgente (+20%)", amount: a)); list += a }
        r.list = round(list, to: 50)

        func addm(_ t: String, _ a: Double) { r.monthlyLines.append(PriceLine(group: "Mensual", text: t, amount: a)); r.monthly += a }
        addm("Hosting, seguridad, SSL, respaldos", rates.mensual)
        let h = Catalog.opt("horas", q.horas)
        addm("Cambios: " + h.t.lowercased(), px(h.p))
        let am = blog ? (Int(q.artmes) ?? 0) : 0
        if am > 0 { addm("\(am) artículos al mes", Double(am) * px(q.autor == "yo" ? 100 : 25)) }
        if q.idioma == "bi" { addm("Dos idiomas", px(25)) }
        if q.tienda != "no" || q.membresia == "si" { addm("Soporte de tienda/pagos", px(50)) }
        if q.reporte == "si" { addm("Reporte de visitas", px(30)) }

        r.special = round(r.list * (1 - Double(q.descuento) / 100), to: 50)
        r.floor = round(r.list * (1 - Double(aj.piso) / 100), to: 50)
        r.specialMonthly = round(r.monthly * (1 - Double(q.descMo) / 100), to: 5)
        r.iva = q.iva == "si" ? 0.13 : 0
        return r
    }

    static func terms(_ q: Quote, _ aj: Ajustes) -> [String] {
        var out = ["50% para empezar y 50% al entregar.", "Cambios fuera de las horas incluidas: \(money(aj.rates(q.mercado).hora)) por hora."]
        var third: [String] = []
        if q.reservas != "no" { third.append("la app de citas" + (q.reservas != "agendar" ? " y la comisión de pagos" : "")) }
        if q.extras.contains("newsletter") { third.append("la herramienta de correos") }
        if q.tienda != "no" || q.membresia == "si" { third.append("la plataforma de venta") }
        if q.dominio != "si" { third.append("el dominio") }
        if !third.isEmpty { out.append("El cliente paga directo: " + third.joined(separator: ", ") + ".") }
        if q.fotos == "sesion" { out.append("La sesión de fotos no está incluida.") }
        if q.membresia == "nose" { out.append("Membresía queda como posible fase 2.") }
        return out
    }

    /// Propuesta lista para pegar en WhatsApp.
    static func proposal(_ item: FormItem, _ q: Quote, _ aj: Ajustes) -> String {
        let r = compute(q, aj)
        var l: [String] = []
        l.append("*Propuesta Zeuq Web Studio" + (item.nombre.isEmpty ? "" : " para \(item.nombre)") + "*")
        if !item.negocio.isEmpty { l.append(item.negocio) }
        l.append("")
        l.append("*Tu página incluye:*")
        for x in r.lines {
            let t = x.text.replacingOccurrences(of: #" \(\$[\d,]+ c/u\)"#, with: "", options: .regularExpression)
            l.append("• " + t)
        }
        if q.idioma == "bi" { l.append("• Versión en inglés y español") }
        if q.plazo == "urgente" { l.append("• Entrega urgente") }
        l.append("")
        if q.descuento > 0 {
            l.append("Precio regular: \(money(r.list))")
            l.append("*Precio especial para ti: \(money(r.special))*")
        } else {
            l.append("*Precio de la página: \(money(r.special))*")
        }
        if r.iva > 0 { l.append("Total con IVA (13%): \(money(r.specialIva))") }
        l.append("Adelanto para empezar: \(money(r.deposit))")
        l.append("")
        l.append(q.descMo > 0 ? "*Mantenimiento mensual: \(money(r.specialMonthly))* (regular \(money(r.monthly)))" : "*Mantenimiento mensual: \(money(r.specialMonthly))*")
        for m in r.monthlyLines { l.append("• " + m.text) }
        l.append("")
        if r.iva > 0 { l.append("_El mantenimiento mensual se cobra más IVA (13%)._") }
        for t in terms(q, aj) { l.append("_" + t + "_") }
        return l.joined(separator: "\n")
    }
}
