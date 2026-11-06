import Foundation

// Tipos del seguimiento (sin interfaz), para poder probarlos fuera de la app.

struct Evento: Codable, Equatable, Identifiable {
    var estado: String
    var fecha: String
    var id: String { estado + fecha }
}

struct Pagos: Codable, Equatable {
    /// Fecha (ISO) en que te pagaron; nil si está pendiente
    var adelanto: String?
    var saldo: String?
    /// Mes del primer cobro de mantenimiento, "2026-12"
    var inicioMantenimiento: String?
    /// Mes "2026-12" → fecha de pago
    var mensualidades: [String: String] = [:]
}

struct RegistroHoras: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var fecha: String
    var horas: Double
    var nota: String
    var mes: String { String(fecha.prefix(7)) }
}

enum Mes {
    static func key(_ d: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: d)
        return String(format: "%04d-%02d", c.year ?? 2026, c.month ?? 1)
    }
    static func next(_ k: String) -> String {
        let p = k.split(separator: "-").compactMap { Int($0) }
        guard p.count == 2 else { return k }
        return p[1] == 12 ? String(format: "%04d-01", p[0] + 1) : String(format: "%04d-%02d", p[0], p[1] + 1)
    }
    static func prev(_ k: String) -> String {
        let p = k.split(separator: "-").compactMap { Int($0) }
        guard p.count == 2 else { return k }
        return p[1] == 1 ? String(format: "%04d-12", p[0] - 1) : String(format: "%04d-%02d", p[0], p[1] - 1)
    }
    /// Meses desde "desde" hasta "hasta", inclusive
    static func range(_ desde: String, _ hasta: String) -> [String] {
        var out: [String] = []
        var m = desde
        while m <= hasta && out.count < 240 { out.append(m); m = next(m) }
        return out
    }
    static func nombre(_ k: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CR")
        f.dateFormat = "yyyy-MM"
        guard let d = f.date(from: k) else { return k }
        f.dateFormat = "LLLL yyyy"
        return f.string(from: d).capitalized
    }
}

func nowISO() -> String { ISO8601DateFormatter().string(from: Date()) }

func shortDate(_ iso: String?) -> String {
    guard let iso, let d = ISO8601DateFormatter().date(from: iso) else { return "" }
    return d.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "es_CR")))
}

extension FormItem {
    /// Fecha en que se mandó la propuesta (la última vez)
    var enviadaEl: Date? {
        guard let e = historial?.last(where: { $0.estado == "enviada" }) else { return nil }
        return ISO8601DateFormatter().date(from: e.fecha)
    }
    /// La propuesta lleva 3 días o más sin respuesta
    var necesitaSeguimiento: Bool {
        guard estado == "enviada", let d = enviadaEl else { return false }
        return Date().timeIntervalSince(d) >= 3 * 24 * 3600
    }
    var horasIncluidas: Double { Double(quote.horas) ?? 1 }
    func horasUsadas(_ mes: String) -> Double { (horasLog ?? []).filter { $0.mes == mes }.reduce(0) { $0 + $1.horas } }
    /// La mensualidad está pendiente este mes
    func mensualidadPendiente(_ mes: String = Mes.key()) -> Bool {
        guard estado == "entregada", let inicio = pagos?.inicioMantenimiento, inicio <= mes else { return false }
        return pagos?.mensualidades[mes] == nil
    }
}



/// Lee la fecha que manda GitHub, por ejemplo "2027-11-06 06:00:00 UTC".
func parseGitHubDate(_ s: String?) -> Date? {
    guard let s, !s.isEmpty else { return nil }
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    for fmt in ["yyyy-MM-dd HH:mm:ss 'UTC'", "yyyy-MM-dd HH:mm:ss Z", "yyyy-MM-dd"] {
        f.dateFormat = fmt
        if let d = f.date(from: s) { return d }
    }
    return nil
}

/// Avisos de mantenimiento de la app: tokens por vencer y tipo de cambio sin actualizar.
struct Aviso: Identifiable, Equatable {
    let id: String
    let titulo: String
    let detalle: String
}

enum Avisos {
    static func dias(hasta d: Date, desde hoy: Date = Date()) -> Int {
        Int((d.timeIntervalSince(hoy) / 86400).rounded(.down))
    }

    static func fecha(_ d: Date) -> String {
        d.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "es_CR")))
    }

    static func calcular(appToken: Date?, gastosToken: Date?, tipoCambioFecha: String?, hoy: Date = Date()) -> [Aviso] {
        var out: [Aviso] = []
        func token(_ id: String, _ nombre: String, _ d: Date?, _ como: String) {
            guard let d else { return }
            let n = dias(hasta: d, desde: hoy)
            guard n <= 14 else { return }
            let cuando = n < 0 ? "venció el \(fecha(d))" : n == 0 ? "vence hoy" : "vence en \(n) día\(n == 1 ? "" : "s") (\(fecha(d)))"
            // El id cambia en 14, 7, 3 y 1 días para volver a avisar
            let tramo = n <= 1 ? 1 : n <= 3 ? 3 : n <= 7 ? 7 : 14
            out.append(Aviso(id: "\(id)-\(tramo)", titulo: "El \(nombre) \(cuando)", detalle: como))
        }
        token("app", "token de la app", appToken,
              "Crea uno nuevo en GitHub (Developer settings → Fine-grained tokens) con los mismos permisos y pégalo en Ajustes → Quitar token, en cada dispositivo.")
        token("gastos", "token del tipo de cambio", gastosToken,
              "Crea uno nuevo de solo lectura para control-gastos-datos y reemplaza el secret GASTOS_TOKEN en el repo zeuq-confirmaciones.")
        if let f = tipoCambioFecha, let d = parseGitHubDate(f), dias(hasta: hoy, desde: d) >= 3 {
            out.append(Aviso(id: "tc-\(f)", titulo: "El tipo de cambio no se actualiza desde el \(fecha(d))",
                             detalle: "Revisa que el proceso «Tipo de cambio» de tu app de gastos esté funcionando. Mientras tanto se usa el último dato."))
        }
        return out
    }
}
