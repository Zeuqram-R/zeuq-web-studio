import SwiftUI
import LocalAuthentication

/// Bloqueo con Face ID, Touch ID o el código del dispositivo.
enum Bloqueo {
    static let key = "bloqueo"

    static var nombre: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "el código del dispositivo"
        }
    }

    /// Pide la cara, la huella o el código. Devuelve true si se pudo verificar.
    static func verificar(_ motivo: String = "Desbloquear Zeuq") async -> Bool {
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Cancelar"
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Sin código ni biometría configurados no hay con qué bloquear
            return true
        }
        do { return try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: motivo) }
        catch { return false }
    }
}

struct LockView: View {
    let onUnlock: () -> Void
    @State private var trying = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Text("Zeuq está bloqueada").font(.title2.weight(.bold))
                Text("Tiene datos de tus clientes.").foregroundStyle(.secondary)
                Button {
                    unlock()
                } label: {
                    Label("Desbloquear con \(Bloqueo.nombre)", systemImage: "faceid").frame(minWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(trying)
            }
            .padding()
        }
        .task { unlock() }
    }

    private func unlock() {
        guard !trying else { return }
        trying = true
        Task {
            if await Bloqueo.verificar() { onUnlock() }
            trying = false
        }
    }
}
