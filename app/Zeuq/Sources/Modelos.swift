import Foundation

/// Valor JSON genérico: las respuestas del formulario pueden ser texto, números o listas.
enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n):
            if n == n.rounded(), abs(n) < 1e15 { try c.encode(Int(n)) } else { try c.encode(n) }
        case .bool(let b): try c.encode(b)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        case .null: try c.encodeNil()
        }
    }

    var text: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return n == n.rounded() ? String(Int(n)) : String(n)
        case .bool(let b): return b ? "sí" : "no"
        default: return nil
        }
    }
    var int: Int? {
        switch self {
        case .number(let n): return Int(n)
        case .string(let s): return Int(s)
        default: return nil
        }
    }
    var strings: [String] {
        if case .array(let a) = self { return a.compactMap { $0.text } }
        if let t = text, !t.isEmpty { return [t] }
        return []
    }
}

/// Lo que eligió el cliente más tus ajustes de precio para esta cotización.
struct Quote: Codable, Equatable {
    var mercado = "fl"
    var iva = "no"
    var diseno = "plantilla"
    var paginas: [String] = []
    var reservas = "no"
    var modalidad = "presencial"
    var tienda = "no"
    var membresia = "no"
    var formulario = "no"
    var extras: [String] = []
    var blog = "no"
    var autor = "el"
    var articulos = 0
    var videos = "no"
    var logo = "si"
    var fotos = "si"
    var textos = "el"
    var dominio = "si"
    var idioma = "en"
    var plazo = "normal"
    var horas = "1"
    var artmes = "0"
    var reporte = "no"
    var descuento = 0
    var descMo = 0

    init() {}

    // Lee cotizaciones guardadas aunque les falten campos (por ejemplo, de una versión vieja de la app).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Quote()
        func s(_ k: CodingKeys, _ def: String) -> String { (try? c.decodeIfPresent(String.self, forKey: k)) ?? nil ?? def }
        func a(_ k: CodingKeys) -> [String] { (try? c.decodeIfPresent([String].self, forKey: k)) ?? nil ?? [] }
        func i(_ k: CodingKeys, _ def: Int) -> Int { (try? c.decodeIfPresent(Int.self, forKey: k)) ?? nil ?? def }
        mercado = s(.mercado, d.mercado); iva = s(.iva, d.iva); diseno = s(.diseno, d.diseno); paginas = a(.paginas)
        reservas = s(.reservas, d.reservas); modalidad = s(.modalidad, d.modalidad); tienda = s(.tienda, d.tienda)
        membresia = s(.membresia, d.membresia); formulario = s(.formulario, d.formulario); extras = a(.extras)
        blog = s(.blog, d.blog); autor = s(.autor, d.autor); articulos = i(.articulos, 0); videos = s(.videos, d.videos)
        logo = s(.logo, d.logo); fotos = s(.fotos, d.fotos); textos = s(.textos, d.textos); dominio = s(.dominio, d.dominio)
        idioma = s(.idioma, d.idioma); plazo = s(.plazo, d.plazo); horas = s(.horas, d.horas); artmes = s(.artmes, d.artmes)
        reporte = s(.reporte, d.reporte); descuento = i(.descuento, 0); descMo = i(.descMo, 0)
    }

    /// Arma la cotización inicial a partir de las respuestas del formulario.
    static func from(_ d: [String: JSONValue]) -> Quote {
        var q = Quote()
        func s(_ k: String, _ v: inout String) { if let t = d[k]?.text, !t.isEmpty { v = t } }
        s("diseno", &q.diseno); s("reservas", &q.reservas); s("modalidad", &q.modalidad)
        s("tienda", &q.tienda); s("membresia", &q.membresia); s("formulario", &q.formulario)
        s("blog", &q.blog); s("autor", &q.autor); s("videos", &q.videos); s("logo", &q.logo)
        s("fotos", &q.fotos); s("textos", &q.textos); s("dominio", &q.dominio); s("idioma", &q.idioma)
        s("plazo", &q.plazo); s("horas", &q.horas); s("artmes", &q.artmes); s("reporte", &q.reporte)
        q.paginas = d["paginas"]?.strings ?? []
        q.extras = d["extras"]?.strings ?? []
        q.articulos = max(0, min(30, d["articulos"]?.int ?? 0))
        // Si el WhatsApp es de Costa Rica, arranca con tarifas de Costa Rica
        let tel = (d["whatsapp"]?.text ?? "").filter { $0.isNumber || $0 == "+" }
        if tel.hasPrefix("+506") || (tel.count == 8 && !tel.hasPrefix("+")) { q.mercado = "cr" }
        return q
    }
}

/// Un formulario recibido (un archivo formularios/<id>.json del repo privado).
struct FormItem: Codable, Identifiable, Equatable {
    var id: String
    var fecha: String
    var lang: String?
    var estado: String
    var confirmado: String?
    var data: [String: JSONValue]
    var cotizacion: Quote?

    var nombre: String { data["nombre"]?.text ?? "" }
    var negocio: String { data["negocio"]?.text ?? "" }
    var email: String { data["email"]?.text ?? "" }
    var whatsapp: String { data["whatsapp"]?.text ?? "" }
    var rubro: String { data["rubro"]?.text ?? "" }
    var presupuesto: String { data["presupuesto"]?.text ?? "" }
    var titulo: String {
        let n = nombre.isEmpty ? "Sin nombre" : nombre
        return negocio.isEmpty ? n : "\(n) · \(negocio)"
    }
    var date: Date? {
        let f = ISO8601DateFormatter()
        return f.date(from: fecha)
    }
    var quote: Quote { cotizacion ?? Quote.from(data) }
}

struct MarketRates: Codable, Equatable {
    var base: Double
    var mensual: Double
    var hora: Double
}

/// Tus tarifas. Se guardan en ajustes.json del repo privado para que sean iguales en todos tus dispositivos.
struct Ajustes: Codable, Equatable {
    var fl = MarketRates(base: 900, mensual: 75, hora: 40)
    var cr = MarketRates(base: 450, mensual: 35, hora: 20)
    var piso = 25

    func rates(_ mercado: String) -> MarketRates { mercado == "cr" ? cr : fl }
}

enum Textos {
    static let presupuesto: [String: String] = [
        "<1000": "Menos de $1,000", "1000-2500": "$1,000 a $2,500", "2500-5000": "$2,500 a $5,000",
        ">5000": "Más de $5,000", "nose": "No está seguro",
    ]
    static let presupuestoMax: [String: Double] = [
        "<1000": 1000, "1000-2500": 2500, "2500-5000": 5000, ">5000": .infinity,
    ]
    static let objetivo: [String: String] = [
        "info": "Mostrar quién es", "clientes": "Conseguir clientes", "agendar": "Agendar citas",
        "vender": "Vender", "contenido": "Compartir contenido",
    ]
}

func money(_ n: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: "en_US")
    f.maximumFractionDigits = 0
    return "$" + (f.string(from: NSNumber(value: n.rounded())) ?? String(Int(n)))
}
