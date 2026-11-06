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
// La cotización guardada sin algunos campos se debe poder leer
let partial = try JSONDecoder().decode(Quote.self, from: Data(#"{"mercado":"cr","descuento":10}"#.utf8))
if partial.mercado != "cr" || partial.descuento != 10 || partial.diseno != "plantilla" { print("❌ lectura parcial"); fails += 1 } else { print("✅ lectura parcial") }
exit(fails == 0 ? 0 : 1)
