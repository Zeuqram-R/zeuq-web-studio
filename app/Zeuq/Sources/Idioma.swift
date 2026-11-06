import Foundation
import NaturalLanguage

/// Revisa si quedó algo en otro idioma: por ejemplo, un concepto en español en una propuesta en inglés.
enum IdiomaCheck {
    private static let es: Set<String> = ["de", "la", "el", "los", "las", "y", "para", "con", "del", "en", "por", "una", "un", "que",
                                          "página", "pagina", "contenido", "diseño", "fotos", "cambios", "mes", "mensual", "migrar",
                                          "correo", "tienda", "citas", "redes", "sesión", "sesion", "nuevo", "nueva", "logo", "textos"]
    private static let en: Set<String> = ["the", "and", "for", "with", "of", "to", "a", "an", "your", "page", "content", "design",
                                          "photos", "changes", "month", "monthly", "migrate", "email", "store", "booking", "social",
                                          "session", "new", "copy", "setup", "website", "site"]

    /// "es", "en" o nil si no se puede saber (texto muy corto o mezclado).
    static func detect(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 3 else { return nil }
        let r = NLLanguageRecognizer()
        r.languageConstraints = [.english, .spanish]
        r.processString(t)
        let h = r.languageHypotheses(withMaximum: 2)
        var sEs = h[.spanish] ?? 0
        var sEn = h[.english] ?? 0
        // Ayuda para textos cortos: palabras típicas y letras que solo usa el español
        let words = t.lowercased().split { !$0.isLetter }.map(String.init)
        let hitsEs = words.filter { es.contains($0) }.count
        let hitsEn = words.filter { en.contains($0) }.count
        sEs += Double(hitsEs) * 0.25
        sEn += Double(hitsEn) * 0.25
        if t.range(of: "[áéíóúñ¿¡]", options: [.regularExpression, .caseInsensitive]) != nil { sEs += 0.5 }
        guard abs(sEs - sEn) >= 0.3 else { return nil }
        return sEs > sEn ? "es" : "en"
    }

    struct Issue: Identifiable, Hashable {
        let text: String
        let detected: String
        var id: String { text }
    }

    /// Lo que escribiste tú (conceptos propios) y no está en el idioma de la propuesta, sin contar lo que marcaste como bien.
    static func issues(_ q: Quote, lang: String) -> [Issue] {
        q.custom.compactMap { c in
            let t = c.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, !q.ignorarIdioma.contains(t), let d = detect(t), d != lang else { return nil }
            return Issue(text: t, detected: d)
        }
    }

    static func nombre(_ l: String) -> String { l == "en" ? "inglés" : "español" }
}
