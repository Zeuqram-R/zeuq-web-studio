import Foundation

/// Contenido de la propuesta para el cliente, en español o inglés.
/// Lo usan el texto para WhatsApp y el PDF, así los dos dicen lo mismo.
struct ProposalContent {
    struct Row { let label: String; let value: String; var bold = false }

    var lang: String
    var title: String
    var clientName: String
    var business: String
    var greeting: String
    var includesTitle: String
    var includes: [String]
    var priceRows: [Row]
    var monthlyTitle: String
    var monthlyPrice: String
    var monthlyItems: [String]
    var termsTitle: String
    var terms: [String]
    var validity: String
    var dateText: String
    var number: String
    var signature: String
}

enum Proposal {
    static func t(_ lang: String, _ es: String, _ en: String) -> String { lang == "en" ? en : es }

    private static let optionText: [String: (String, String)] = [
        "diseno.semi": ("Diseño con detalles de tu marca", "Design with your brand's details"),
        "diseno.medida": ("Diseño único, hecho desde cero", "Fully custom design, built from scratch"),
        "paginas.testimonios": ("Página de testimonios", "Testimonials page"),
        "paginas.portafolio": ("Portafolio de trabajos", "Portfolio page"),
        "paginas.galeria": ("Galería de fotos", "Photo gallery"),
        "paginas.faq": ("Preguntas frecuentes", "FAQ page"),
        "paginas.precios": ("Página de precios y paquetes", "Pricing and packages page"),
        "paginas.equipo": ("Página del equipo", "Team page"),
        "reservas.agendar": ("Reservas en línea con recordatorios", "Online booking with reminders"),
        "reservas.cobrar": ("Reservas con pago en línea", "Online booking with payment"),
        "reservas.paquetes": ("Venta de paquetes de citas", "Appointment packages for sale"),
        "modalidad.online": ("Citas en línea con enlace automático", "Online sessions with automatic video link"),
        "modalidad.ambas": ("Citas presenciales y en línea", "In-person and online sessions"),
        "tienda.pocos": ("Tienda en línea (hasta 10 productos)", "Online store (up to 10 products)"),
        "tienda.completa": ("Tienda en línea completa", "Full online store"),
        "tienda.digitales": ("Venta de productos digitales", "Digital product sales"),
        "membresia.si": ("Membresía con contenido exclusivo", "Members-only content"),
        "formulario.si": ("Formulario especial (evaluación o inscripción)", "Custom form (intake or sign-up)"),
        "extras.newsletter": ("Suscripción por correo (newsletter)", "Email newsletter sign-up"),
        "extras.instagram": ("Tu Instagram dentro de la página", "Your Instagram feed on the site"),
        "extras.seo": ("SEO básico para aparecer en Google", "Basic SEO to show up on Google"),
        "extras.google": ("Perfil de Google Business", "Google Business profile"),
        "extras.calculadora": ("Calculadora o herramienta interactiva", "Calculator or interactive tool"),
        "blog.simple": ("Blog", "Blog"),
        "blog.completo": ("Blog con categorías y buscador", "Blog with categories and search"),
        "videos.biblioteca": ("Biblioteca de videos organizada", "Organized video library"),
        "logo.no": ("Logo sencillo", "Simple logo"),
        "fotos.banco": ("Fotos profesionales de banco de imágenes", "Professional stock photos"),
        "textos.yo": ("Redacción de los textos de la página", "Copywriting for all pages"),
    ]

    /// Nombre de cada concepto como lo ve el cliente.
    static func label(_ l: PriceLine, _ q: Quote, _ lang: String) -> String {
        if l.customID != nil { return l.text }
        let k = l.key
        func opt(_ id: String, _ v: String) -> String {
            if let p = optionText["\(id).\(v)"] { return lang == "en" ? p.1 : p.0 }
            return Catalog.opt(id, v).t
        }
        switch k {
        case "base": return t(lang, "Sitio de 4 páginas: Inicio, Sobre mí, Servicios y Contacto, adaptado a celular",
                              "4-page website: Home, About, Services and Contact, mobile-friendly")
        case "diseno", "reservas", "modalidad", "tienda", "blog":
            return opt(k, Pricing.value(q, k))
        case "membresia": return opt("membresia", "si")
        case "formulario": return opt("formulario", "si")
        case "videos": return opt("videos", "biblioteca")
        case "logo": return opt("logo", "no")
        case "fotos": return opt("fotos", "banco")
        case "textos": return opt("textos", "yo")
        case "articulos": return t(lang, "\(q.articulos) artículo\(q.articulos == 1 ? "" : "s") listos para el lanzamiento",
                                   "\(q.articulos) article\(q.articulos == 1 ? "" : "s") ready at launch")
        case "m.base": return t(lang, "Hosting, seguridad, certificado SSL y respaldos", "Hosting, security, SSL certificate and backups")
        case "m.horas": return t(lang, "Hasta \(q.horas) h de cambios al mes", "Up to \(q.horas) h of changes per month")
        case "m.artmes": return t(lang, "\(q.artmes) artículos nuevos al mes", "\(q.artmes) new articles per month")
        case "m.idioma": return t(lang, "Mantener las dos versiones de idioma", "Keeping both language versions up to date")
        case "m.tienda": return t(lang, "Soporte de tienda y pagos", "Store and payments support")
        case "m.reporte": return t(lang, "Reporte mensual de visitas", "Monthly traffic report")
        default:
            if k.hasPrefix("paginas.") || k.hasPrefix("extras.") {
                let parts = k.split(separator: ".", maxSplits: 1).map(String.init)
                return opt(parts[0], parts[1])
            }
            return l.text
        }
    }

    static func terms(_ q: Quote, _ aj: Ajustes, _ lang: String) -> [String] {
        let hora = money(aj.rates(q.mercado).hora)
        var out = [t(lang, "50% para empezar y 50% al entregar.", "50% to start and 50% on delivery."),
                   t(lang, "Cambios fuera de las horas incluidas: \(hora) por hora.", "Changes beyond the included hours: \(hora) per hour.")]
        var third: [String] = []
        if q.reservas != "no" {
            third.append(t(lang, "la app de citas", "the booking app") + (q.reservas != "agendar" ? t(lang, " y la comisión de pagos", " and payment processing fees") : ""))
        }
        if q.extras.contains("newsletter") { third.append(t(lang, "la herramienta de correos", "the email marketing tool")) }
        if q.tienda != "no" || q.membresia == "si" { third.append(t(lang, "la plataforma de venta", "the sales platform")) }
        if q.dominio != "si" { third.append(t(lang, "el dominio", "the domain name")) }
        if !third.isEmpty {
            out.append(t(lang, "Pagas directamente: ", "You pay directly for: ") + third.joined(separator: ", ") + ".")
        }
        if q.fotos == "sesion" { out.append(t(lang, "La sesión de fotos no está incluida.", "The photo shoot is not included.")) }
        if q.membresia == "nose" { out.append(t(lang, "La membresía puede agregarse más adelante como una segunda fase.", "Members-only content can be added later as a second phase.")) }
        if q.iva == "si" { out.append(t(lang, "El mantenimiento mensual se cobra más IVA (13%).", "Monthly maintenance is billed plus 13% VAT.")) }
        return out
    }

    static func content(_ item: FormItem, _ q: Quote, _ aj: Ajustes, lang: String, date: Date = Date(), enColones: Bool = false) -> ProposalContent {
        let r = Pricing.compute(q, aj)
        let first = item.nombre.split(separator: " ").first.map(String.init) ?? ""
        let loc = Locale(identifier: lang == "en" ? "en_US" : "es_CR")
        let valid = Calendar.current.date(byAdding: .day, value: 15, to: date) ?? date
        let fmt = Date.FormatStyle(date: .long, time: .omitted).locale(loc)

        var includes = r.lines.map { label($0, q, lang) }
        if q.idioma == "bi" { includes.append(t(lang, "Versión en inglés y español", "English and Spanish versions")) }
        if q.plazo == "urgente" { includes.append(t(lang, "Entrega urgente (menos de 2 semanas)", "Rush delivery (under 2 weeks)")) }

        var rows: [ProposalContent.Row] = []
        if q.descuento > 0 {
            rows.append(.init(label: t(lang, "Precio regular", "Regular price"), value: money(r.list)))
            rows.append(.init(label: t(lang, "Precio especial para ti", "Your special price"), value: money(r.special), bold: true))
        } else {
            rows.append(.init(label: t(lang, "Precio de la página", "Website price"), value: money(r.special), bold: true))
        }
        if r.iva > 0 { rows.append(.init(label: t(lang, "Total con IVA (13%)", "Total with 13% VAT"), value: money(r.specialIva), bold: true)) }
        rows.append(.init(label: t(lang, "Adelanto para empezar (50%)", "Deposit to start (50%)"), value: money(r.deposit)))
        let tc = aj.tipoCambio
        if enColones {
            rows.append(.init(label: t(lang, "En colones (tipo de cambio ₡\(Int(tc)))", "In colones (₡\(Int(tc)) per $1)"),
                              value: "≈ " + colones(r.specialIva, tc)))
        }

        let monthly = money(r.specialMonthly) + t(lang, "/mes", "/month")
            + (q.descMo > 0 ? t(lang, " (regular \(money(r.monthly)))", " (regular \(money(r.monthly)))") : "")
            + (enColones ? " ≈ " + colones(r.specialMonthly, tc) : "")

        let num = "ZWS-" + item.id.suffix(6).uppercased()

        return ProposalContent(
            lang: lang,
            title: t(lang, "Propuesta de página web", "Website proposal"),
            clientName: item.nombre,
            business: item.negocio,
            greeting: first.isEmpty ? t(lang, "Gracias por tu interés. Esta es la propuesta para tu página:", "Thanks for your interest. Here's the proposal for your website:")
                : t(lang, "Hola \(first), gracias por tu interés. Esta es la propuesta para tu página:", "Hi \(first), thanks for your interest. Here's the proposal for your website:"),
            includesTitle: t(lang, "Tu página incluye", "Your website includes"),
            includes: includes,
            priceRows: rows,
            monthlyTitle: t(lang, "Mantenimiento mensual", "Monthly maintenance"),
            monthlyPrice: monthly,
            monthlyItems: r.monthlyLines.map { label($0, q, lang) },
            termsTitle: t(lang, "Condiciones", "Terms"),
            terms: terms(q, aj, lang),
            validity: t(lang, "Precios válidos hasta el \(valid.formatted(fmt)).", "Prices valid until \(valid.formatted(fmt))."),
            dateText: date.formatted(fmt),
            number: num,
            signature: "Jose · Zeuq Web Studio"
        )
    }

    /// Texto para WhatsApp (con *negritas* y _cursivas_).
    static func text(_ c: ProposalContent) -> String {
        var l: [String] = []
        l.append("*\(c.title) · Zeuq Web Studio*")
        if !c.business.isEmpty { l.append(c.business) }
        l.append("")
        l.append(c.greeting)
        l.append("")
        l.append("*\(c.includesTitle):*")
        l += c.includes.map { "• " + $0 }
        l.append("")
        for r in c.priceRows { l.append(r.bold ? "*\(r.label): \(r.value)*" : "\(r.label): \(r.value)") }
        l.append("")
        l.append("*\(c.monthlyTitle): \(c.monthlyPrice)*")
        l += c.monthlyItems.map { "• " + $0 }
        l.append("")
        l += c.terms.map { "_" + $0 + "_" }
        l.append("_" + c.validity + "_")
        l.append("")
        l.append(c.signature)
        return l.joined(separator: "\n")
    }
}
