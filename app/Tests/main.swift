import Foundation

// Compara el cálculo de la app con el del cotizador web (valores esperados en cases.json).
struct Case: Decodable { let name: String; let q: [String: JSONValue]; let expected: [String: Double] }

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
var fails = 0
for c in cases {
    var q = Quote.from(c.q)
    q.mercado = c.q["mercado"]?.text ?? "fl"
    q.iva = c.q["iva"]?.text ?? "no"
    q.descuento = c.q["descuento"]?.int ?? 0
    q.descMo = c.q["descMo"]?.int ?? 0
    let r = Pricing.compute(q, Ajustes())
    let got: [String: Double] = ["list": r.list, "monthly": r.monthly, "special": r.special, "specialMonthly": r.specialMonthly,
                                 "specialIva": r.specialIva, "floor": r.floor, "lines": Double(r.lines.count)]
    for (k, v) in c.expected where got[k] != v {
        print("❌ \(c.name) \(k): app \(got[k] ?? -1), web \(v)"); fails += 1
    }
    if fails == 0 { print("✅ \(c.name)") }
}
// Precios cambiados a mano y conceptos propios
var qo = Quote()
qo.overrides = ["base": 700]
qo.custom = [CustomLine(text: "Migración", amount: 200), CustomLine(text: "Correo", amount: 10, monthly: true)]
let ro = Pricing.compute(qo, Ajustes())
if ro.list != 900 || ro.monthly != 85 || ro.lines.first?.original != 900 { print("❌ precios a mano: \(ro.list) \(ro.monthly)"); fails += 1 } else { print("✅ precios a mano") }
// Propuesta en los dos idiomas
let fi = FormItem(id: "2026-11-05_abc123def0", fecha: "2026-11-05T00:00:00Z", lang: "en", estado: "nuevo", confirmado: nil,
                  data: ["nombre": .string("Juan Ramos"), "negocio": .string("JR Fitness")], cotizacion: nil)
var qp = Quote(); qp.reservas = "cobrar"; qp.paginas = ["testimonios"]; qp.idioma = "bi"; qp.descuento = 10
let en = Proposal.text(Proposal.content(fi, qp, Ajustes(), lang: "en"))
let es = Proposal.text(Proposal.content(fi, qp, Ajustes(), lang: "es"))
print("----- EN -----\n" + en + "\n----- ES -----\n" + es)
if !en.contains("Online booking with payment") || !en.contains("Your special price") || !es.contains("Reservas con pago en línea") { print("❌ propuesta bilingüe"); fails += 1 } else { print("✅ propuesta bilingüe") }
// Seguimiento: meses, mensualidades y horas
if Mes.next("2026-12") != "2027-01" || Mes.prev("2027-01") != "2026-12" || Mes.range("2026-11", "2027-02").count != 4 { print("❌ meses"); fails += 1 } else { print("✅ meses") }
var fs = fi
fs.estado = "entregada"
fs.pagos = Pagos(adelanto: nil, saldo: nil, inicioMantenimiento: "2026-01", mensualidades: [:])
fs.horasLog = [RegistroHoras(fecha: "2026-11-03T10:00:00Z", horas: 2.5, nota: ""), RegistroHoras(fecha: "2026-10-03T10:00:00Z", horas: 4, nota: "")]
if !fs.mensualidadPendiente("2026-11") || fs.horasUsadas("2026-11") != 2.5 { print("❌ pagos y horas"); fails += 1 } else { print("✅ pagos y horas") }
let enc = try JSONEncoder().encode(fs)
let back = try JSONDecoder().decode(FormItem.self, from: enc)
if back != fs { print("❌ guardar y leer seguimiento"); fails += 1 } else { print("✅ guardar y leer seguimiento") }
// Precios de opciones cambiados en Ajustes
var ajx = Ajustes()
ajx.precios["fl"] = ["diseno.semi": 500, "idioma.bi": 30]
var qx = Quote(); qx.diseno = "semi"; qx.idioma = "bi"
let rx = Pricing.compute(qx, ajx)
// base 900 + diseño 500 = 1400; +30% = 1820 → redondeo a 50 = 1800
if rx.lines.first(where: { $0.key == "diseno" })?.amount != 500 || rx.list != 1800 { print("❌ precios de Ajustes: \(rx.list)"); fails += 1 } else { print("✅ precios de Ajustes") }
let ajOld = try JSONDecoder().decode(Ajustes.self, from: Data(#"{"fl":{"base":1000,"mensual":80,"hora":45},"cr":{"base":450,"mensual":35,"hora":20},"piso":20}"#.utf8))
if ajOld.fl.base != 1000 || ajOld.piso != 20 || !ajOld.precios.isEmpty { print("❌ ajustes viejos"); fails += 1 } else { print("✅ ajustes viejos") }
// Colones
if colones(1000, 460) != "₡460.000" { print("❌ colones: \(colones(1000, 460))"); fails += 1 } else { print("✅ colones") }
var qc = Quote(); qc.mercado = "cr"
let cc = Proposal.text(Proposal.content(fi, qc, Ajustes(), lang: "es", enColones: true))
if !cc.contains("En colones") { print("❌ propuesta en colones"); fails += 1 } else { print("✅ propuesta en colones") }
// La cotización guardada sin algunos campos se debe poder leer
let partial = try JSONDecoder().decode(Quote.self, from: Data(#"{"mercado":"cr","descuento":10}"#.utf8))
if partial.mercado != "cr" || partial.descuento != 10 || partial.diseno != "plantilla" { print("❌ lectura parcial"); fails += 1 } else { print("✅ lectura parcial") }
exit(fails == 0 ? 0 : 1)
