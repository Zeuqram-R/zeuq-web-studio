import SwiftUI

/// La propuesta como documento con la marca de Zeuq (tamaño carta).
struct ProposalDocument: View {
    let c: ProposalContent
    private let blue = Color(red: 0.122, green: 0.310, blue: 0.820)
    private let ink = Color(red: 0.094, green: 0.129, blue: 0.114)
    private let muted = Color(red: 0.357, green: 0.400, blue: 0.376)
    private let soft = Color(red: 0.894, green: 0.918, blue: 0.984)
    private let line = Color(red: 0.851, green: 0.871, blue: 0.847)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Encabezado
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    Text("Z")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(blue, in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ZEUQ WEB STUDIO").font(.system(size: 13, weight: .heavy)).tracking(2).foregroundStyle(ink)
                        Text("zeuq.webstudio@icloud.com").font(.system(size: 9)).foregroundStyle(muted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(c.number).font(.system(size: 10, weight: .semibold)).foregroundStyle(ink)
                    Text(c.dateText).font(.system(size: 9)).foregroundStyle(muted)
                }
            }
            .padding(.bottom, 22)

            Rectangle().fill(blue).frame(height: 3).padding(.bottom, 22)

            Text(c.title.uppercased()).font(.system(size: 26, weight: .heavy)).foregroundStyle(ink)
            Text([c.clientName, c.business].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.system(size: 13, weight: .medium)).foregroundStyle(blue)
                .padding(.top, 2)
            Text(c.greeting).font(.system(size: 11)).foregroundStyle(muted).padding(.top, 12)

            // Lo que incluye
            sectionTitle(c.includesTitle).padding(.top, 20)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(c.includes.enumerated()), id: \.offset) { _, t in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(blue)
                        Text(t).font(.system(size: 11)).foregroundStyle(ink)
                    }
                }
            }

            // Precio
            VStack(spacing: 8) {
                ForEach(Array(c.priceRows.enumerated()), id: \.offset) { _, r in
                    HStack {
                        Text(r.label).font(.system(size: r.bold ? 13 : 11, weight: r.bold ? .bold : .regular))
                        Spacer()
                        Text(r.value).font(.system(size: r.bold ? 18 : 11, weight: r.bold ? .heavy : .regular)).monospacedDigit()
                    }
                    .foregroundStyle(r.bold ? ink : muted)
                }
            }
            .padding(16)
            .background(soft, in: RoundedRectangle(cornerRadius: 10))
            .padding(.top, 20)

            // Mantenimiento
            HStack(alignment: .firstTextBaseline) {
                sectionTitle(c.monthlyTitle)
                Spacer()
                Text(c.monthlyPrice).font(.system(size: 12, weight: .bold)).foregroundStyle(ink).monospacedDigit()
            }
            .padding(.top, 20)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(c.monthlyItems.enumerated()), id: \.offset) { _, t in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(blue).frame(width: 4, height: 4)
                        Text(t).font(.system(size: 11)).foregroundStyle(ink)
                    }
                }
            }

            // Condiciones
            sectionTitle(c.termsTitle).padding(.top, 20)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(c.terms.enumerated()), id: \.offset) { _, t in
                    Text("• " + t).font(.system(size: 9.5)).foregroundStyle(muted)
                }
                Text(c.validity).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(ink).padding(.top, 2)
            }

            Rectangle().fill(line).frame(height: 1).padding(.top, 24)
            HStack {
                Text(c.signature).font(.system(size: 10, weight: .semibold)).foregroundStyle(ink)
                Spacer()
                Text("zeuq.webstudio@icloud.com").font(.system(size: 9)).foregroundStyle(muted)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 44)
        .frame(width: 612, alignment: .topLeading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(1.5).foregroundStyle(blue).padding(.bottom, 8)
    }
}

enum ProposalPDF {
    static let page = CGSize(width: 612, height: 792)

    /// Crea el PDF en una carpeta temporal y devuelve su ubicación.
    @MainActor static func make(_ c: ProposalContent) -> URL? {
        let who = c.business.isEmpty ? c.clientName : c.business
        let base = (c.lang == "en" ? "Zeuq Proposal" : "Propuesta Zeuq") + (who.isEmpty ? "" : " - " + who)
        let safe = base.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safe + ".pdf")
        try? FileManager.default.removeItem(at: url)

        let renderer = ImageRenderer(content: ProposalDocument(c: c))
        var ok = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: page)
            guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            if size.height <= page.height * 1.3 {
                // Una sola página: si se pasa un poco, se achica para que quepa
                let scale = min(1, page.height / size.height)
                ctx.beginPDFPage(nil)
                ctx.saveGState()
                ctx.setFillColor(CGColor(gray: 1, alpha: 1))
                ctx.fill(box)
                ctx.translateBy(x: (page.width - size.width * scale) / 2, y: page.height - size.height * scale)
                ctx.scaleBy(x: scale, y: scale)
                draw(ctx)
                ctx.restoreGState()
                ctx.endPDFPage()
            } else {
                let pages = Int((size.height / page.height).rounded(.up))
                for p in 0..<pages {
                    ctx.beginPDFPage(nil)
                    ctx.saveGState()
                    ctx.setFillColor(CGColor(gray: 1, alpha: 1))
                    ctx.fill(box)
                    ctx.translateBy(x: 0, y: CGFloat(p + 1) * page.height - size.height)
                    draw(ctx)
                    ctx.restoreGState()
                    ctx.endPDFPage()
                }
            }
            ctx.closePDF()
            ok = true
        }
        return ok ? url : nil
    }
}
