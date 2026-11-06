import Foundation
import SwiftUI
import UserNotifications
#if os(iOS)
import BackgroundTasks
#endif

/// Estado de la app: formularios, tarifas y sincronización con el repo privado.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()
    nonisolated static let refreshTaskID = "com.zeuqram.zeuq.refresh"

    @Published var items: [FormItem] = []
    @Published var ajustes = Ajustes()
    @Published var loading = false
    @Published var message: String?
    @Published var lastSync: Date?
    @Published var hasToken = Keychain.get("token") != nil
    /// Último tipo de cambio del BCCR que copió la nube
    @Published var tipoCambio: TipoCambio?
    /// Cuándo vence el token de esta app (lo dice GitHub)
    @Published var appTokenVence: Date?

    var avisos: [Aviso] {
        Avisos.calcular(appToken: appTokenVence, gastosToken: parseGitHubDate(tipoCambio?.tokenVence), tipoCambioFecha: tipoCambio?.fecha)
    }

    private var shas: [String: String] = [:]     // id → sha del archivo en el repo
    private var ajustesSha: String?

    private var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Zeuq", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("cache.json")
    }

    private struct Cache: Codable {
        var items: [FormItem]
        var shas: [String: String]
        var ajustes: Ajustes
        var ajustesSha: String?
        var lastSync: Date?
        var tipoCambio: TipoCambio?
        var appTokenVence: Date?
    }

    init() { loadCache() }

    var client: GitHubClient? { Keychain.get("token").map(GitHubClient.init) }

    func items(estado: String) -> [FormItem] {
        items.filter { $0.estado == estado }.sorted { $0.fecha > $1.fecha }
    }

    func items(grupo: String) -> [FormItem] {
        let estados = Etapa.grupos.first(where: { $0.id == grupo })?.estados ?? []
        return items.filter { estados.contains($0.estado) }.sorted { a, b in
            if a.necesitaSeguimiento != b.necesitaSeguimiento { return a.necesitaSeguimiento }
            return a.fecha > b.fecha
        }
    }

    // MARK: Token

    func saveToken(_ t: String) async -> String? {
        let token = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return "Pega el token." }
        do {
            let canWrite = try await GitHubClient(token: token).checkAccess()
            guard canWrite else { return "El token entra al repo, pero no puede escribir. Dale permiso de Contents: Read and write." }
            Keychain.set("token", token)
            hasToken = true
            await refresh()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func removeToken() {
        Keychain.delete("token")
        hasToken = false
    }

    // MARK: Sincronización

    @discardableResult
    func refresh(notify: Bool = true) async -> Bool {
        guard let c = client, !loading else { return false }
        loading = true
        defer { loading = false }
        do {
            if case let (sha, data)? = try await c.getFile(Repo.settings), let a = try? JSONDecoder().decode(Ajustes.self, from: data) {
                ajustes = a; ajustesSha = sha
            }
            if case let (_, data)? = try? await c.getFile(Repo.exchange), let tc = try? JSONDecoder().decode(TipoCambio.self, from: data) {
                tipoCambio = tc
            }
            if ajustes.tipoCambioAuto, let tc = tipoCambio { ajustes.tipoCambio = tc.venta }
            if let v = parseGitHubDate(c.tokenVence) { appTokenVence = v }
            let files = try await c.list(Repo.folder).filter { $0.name.hasSuffix(".json") }
            var byId = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
            var newShas: [String: String] = [:]
            for f in files {
                let id = String(f.name.dropLast(5))
                newShas[id] = f.sha
                if shas[id] == f.sha, byId[id] != nil { continue }
                if case let (_, data)? = try await c.getFile(f.path), let item = try? JSONDecoder().decode(FormItem.self, from: data) {
                    byId[id] = item
                }
            }
            let ids = Set(newShas.keys)
            items = byId.values.filter { ids.contains($0.id) }.sorted { $0.fecha > $1.fecha }
            shas = newShas
            lastSync = Date()
            message = nil
            saveCache()
            if notify { notifyNew() }
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    func save(_ item: FormItem, note: String) async -> Bool {
        guard let c = client else { message = "Falta el token de GitHub."; return false }
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            var data = try enc.encode(item)
            data.append(0x0A)
            let sha = try await c.putFile("\(Repo.folder)/\(item.id).json", data: data, sha: shas[item.id], message: note)
            shas[item.id] = sha
            if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = item }
            saveCache()
            message = nil
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    /// Cambia la etapa y la anota en el historial con la fecha.
    @discardableResult
    func setEstado(_ item: FormItem, _ estado: String) async -> Bool {
        var it = item
        it.estado = estado
        if it.cotizacion == nil, estado != "nuevo" { it.cotizacion = item.quote }
        it.historial = (it.historial ?? []) + [Evento(estado: estado, fecha: nowISO())]
        if estado == "entregada" {
            var p = it.pagos ?? Pagos()
            if p.inicioMantenimiento == nil { p.inicioMantenimiento = Mes.next(Mes.key()) }
            it.pagos = p
        }
        return await save(it, note: "Etapa: " + Etapa.nombre(estado))
    }

    func saveAjustes(_ a: Ajustes) async -> Bool {
        guard let c = client else { message = "Falta el token de GitHub."; return false }
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            ajustesSha = try await c.putFile(Repo.settings, data: try enc.encode(a), sha: ajustesSha, message: "Tarifas actualizadas")
            ajustes = a
            saveCache()
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    func runConfirmations() async -> Bool {
        guard let c = client else { return false }
        do {
            try await c.runConfirmations()
            message = "Listo. La nube manda las confirmaciones pendientes en uno o dos minutos."
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    // MARK: Caché (para abrir la app sin internet)

    private func loadCache() {
        guard let d = try? Data(contentsOf: cacheURL), let c = try? JSONDecoder().decode(Cache.self, from: d) else { return }
        items = c.items; shas = c.shas; ajustes = c.ajustes; ajustesSha = c.ajustesSha; lastSync = c.lastSync; tipoCambio = c.tipoCambio; appTokenVence = c.appTokenVence
    }

    private func saveCache() {
        let c = Cache(items: items, shas: shas, ajustes: ajustes, ajustesSha: ajustesSha, lastSync: lastSync, tipoCambio: tipoCambio, appTokenVence: appTokenVence)
        if let d = try? JSONEncoder().encode(c) { try? d.write(to: cacheURL, options: .atomic) }
    }

    // MARK: Notificaciones

    nonisolated static func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func notifyNew() {
        let key = "vistos"
        let firstRun = UserDefaults.standard.object(forKey: key) == nil
        var seen = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        let fresh = items.filter { $0.estado == "nuevo" && !seen.contains($0.id) }
        if !firstRun {
            for it in fresh {
                let content = UNMutableNotificationContent()
                content.title = "Nuevo formulario"
                var body = it.titulo
                if let p = Textos.presupuesto[it.presupuesto] { body += " · " + p }
                content.body = body
                content.sound = .default
                let req = UNNotificationRequest(identifier: it.id, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(req)
            }
        }
        seen.formUnion(items.map(\.id))
        UserDefaults.standard.set(Array(seen), forKey: key)

        // Propuestas que llevan 3 días sin respuesta: un aviso por cada envío
        var avisados = Set(UserDefaults.standard.stringArray(forKey: "seguimiento") ?? [])
        for it in items where it.necesitaSeguimiento {
            let k = it.id + (it.historial?.last(where: { $0.estado == "enviada" })?.fecha ?? "")
            guard !avisados.contains(k) else { continue }
            avisados.insert(k)
            let content = UNMutableNotificationContent()
            content.title = "Dale seguimiento"
            content.body = "Le mandaste la propuesta a \(it.titulo) hace 3 días y no ha respondido."
            content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "seg-" + k, content: content, trigger: nil))
        }
        UserDefaults.standard.set(Array(avisados), forKey: "seguimiento")

        // Tokens por vencer y tipo de cambio viejo: un aviso por tramo (14, 7, 3 y 1 días)
        var vistos = Set(UserDefaults.standard.stringArray(forKey: "avisosApp") ?? [])
        for a in avisos where !vistos.contains(a.id) {
            vistos.insert(a.id)
            let content = UNMutableNotificationContent()
            content.title = a.titulo
            content.body = a.detalle
            content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "aviso-" + a.id, content: content, trigger: nil))
        }
        UserDefaults.standard.set(Array(vistos), forKey: "avisosApp")
        #if os(iOS)
        UNUserNotificationCenter.current().setBadgeCount(items.filter { $0.estado == "nuevo" }.count)
        #endif
    }

    #if os(iOS)
    /// Le pide a iOS que vuelva a revisar en segundo plano. iOS decide cuándo (puede tardar).
    nonisolated static func scheduleBackgroundRefresh() {
        let req = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(req)
    }
    #endif
}
