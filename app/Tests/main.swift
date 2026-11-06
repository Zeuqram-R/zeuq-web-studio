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
// La cotización guardada sin algunos campos se debe poder leer
let partial = try JSONDecoder().decode(Quote.self, from: Data(#"{"mercado":"cr","descuento":10}"#.utf8))
if partial.mercado != "cr" || partial.descuento != 10 || partial.diseno != "plantilla" { print("❌ lectura parcial"); fails += 1 } else { print("✅ lectura parcial") }
exit(fails == 0 ? 0 : 1)
