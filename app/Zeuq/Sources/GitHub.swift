import Foundation
import Security

/// Repo privado donde la nube guarda los formularios.
enum Repo {
    static let owner = "Zeuqram-R"
    static let name = "zeuq-confirmaciones"
    static let branch = "main"
    static let folder = "formularios"
    static let settings = "ajustes.json"
    static let exchange = "tipo_cambio.json"
    static let workflow = "confirmar.yml"
}

struct GitHubError: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? {
        switch status {
        case 0: return "Sin conexión a internet."
        case 401: return "El token de GitHub no es válido o ya venció. Pon uno nuevo en Ajustes."
        case 403: return "El token no tiene permiso para esto. Revisa sus permisos en GitHub."
        case 404: return "No encontré el repo zeuq-confirmaciones con ese token."
        case 409: return "Otro dispositivo cambió este formulario al mismo tiempo. Actualiza y vuelve a intentarlo."
        default: return message
        }
    }
}

struct RemoteFile { let name: String; let path: String; let sha: String }

final class GitHubClient {
    private let token: String
    private let session: URLSession
    private let base = "/repos/\(Repo.owner)/\(Repo.name)"
    /// Fecha en que vence este token, según GitHub (llega en cada respuesta)
    private(set) var tokenVence: String?

    init(token: String) {
        self.token = token
        let c = URLSessionConfiguration.default
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.urlCache = nil
        c.timeoutIntervalForRequest = 30
        session = URLSession(configuration: c)
    }

    @discardableResult
    private func call(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> Any? {
        guard let url = URL(string: "https://api.github.com" + path) else { throw GitHubError(status: -1, message: "Dirección inválida") }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        r.setValue("Zeuq-App", forHTTPHeaderField: "User-Agent")
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let data: Data
        let resp: URLResponse
        do { (data, resp) = try await session.data(for: r) } catch { throw GitHubError(status: 0, message: "Sin conexión") }
        guard let http = resp as? HTTPURLResponse else { throw GitHubError(status: 0, message: "Sin conexión") }
        if let v = http.value(forHTTPHeaderField: "github-authentication-token-expiration") { tokenVence = v }
        let json = data.isEmpty ? nil : try? JSONSerialization.jsonObject(with: data)
        guard (200..<300).contains(http.statusCode) else {
            let msg = (json as? [String: Any])?["message"] as? String ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw GitHubError(status: http.statusCode, message: msg)
        }
        return json
    }

    private static func enc(_ path: String) -> String {
        path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
    }

    func checkAccess() async throws -> Bool {
        let r = try await call(base) as? [String: Any] ?? [:]
        return ((r["permissions"] as? [String: Any])?["push"] as? Bool) ?? false
    }

    func list(_ folder: String) async throws -> [RemoteFile] {
        do {
            let r = try await call("\(base)/contents/\(Self.enc(folder))?ref=\(Repo.branch)") as? [[String: Any]] ?? []
            return r.compactMap { e in
                guard e["type"] as? String == "file", let n = e["name"] as? String, let p = e["path"] as? String,
                      let s = e["sha"] as? String else { return nil }
                return RemoteFile(name: n, path: p, sha: s)
            }
        } catch let e as GitHubError where e.status == 404 {
            // Si el token sirve pero la carpeta todavía no existe, no hay formularios
            _ = try await checkAccess()
            return []
        }
    }

    func getFile(_ path: String) async throws -> (sha: String, data: Data)? {
        do {
            let r = try await call("\(base)/contents/\(Self.enc(path))?ref=\(Repo.branch)") as? [String: Any] ?? [:]
            guard let sha = r["sha"] as? String, let c = r["content"] as? String,
                  let d = Data(base64Encoded: c, options: .ignoreUnknownCharacters) else {
                throw GitHubError(status: -1, message: "Archivo dañado")
            }
            return (sha, d)
        } catch let e as GitHubError where e.status == 404 {
            return nil
        }
    }

    func putFile(_ path: String, data: Data, sha: String?, message: String) async throws -> String {
        var body: [String: Any] = ["message": message, "content": data.base64EncodedString(), "branch": Repo.branch]
        if let sha { body["sha"] = sha }
        let r = try await call("\(base)/contents/\(Self.enc(path))", method: "PUT", body: body) as? [String: Any] ?? [:]
        return ((r["content"] as? [String: Any])?["sha"] as? String) ?? ""
    }

    /// Corre el workflow de la nube ahora (manda las confirmaciones pendientes).
    func runConfirmations() async throws {
        try await call("\(base)/actions/workflows/\(Repo.workflow)/dispatches", method: "POST", body: ["ref": Repo.branch])
    }
}

/// El token de GitHub vive solo en el Llavero del dispositivo.
enum Keychain {
    private static let service = "com.zeuqram.zeuq"

    private static func baseQuery(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    static func get(_ key: String) -> String? {
        var q = baseQuery(key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    @discardableResult
    static func set(_ key: String, _ value: String) -> Bool {
        delete(key)
        var q = baseQuery(key)
        q[kSecValueData as String] = Data(value.utf8)
        #if os(iOS)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    static func delete(_ key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
    }
}
