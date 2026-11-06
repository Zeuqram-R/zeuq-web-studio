import SwiftUI

@main
struct ZeuqApp: App {
    @StateObject private var store = Store.shared
    @Environment(\.scenePhase) private var phase
    @AppStorage(Bloqueo.key) private var bloqueo = false
    @State private var locked = UserDefaults.standard.bool(forKey: Bloqueo.key)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Color("AccentColor"))
                .onAppear { Store.requestNotifications() }
                .overlay { if locked { LockView { locked = false } } }
        }
        .onChange(of: phase) { _, p in
            #if os(iOS)
            if p == .background { Store.scheduleBackgroundRefresh() }
            #endif
            if p == .background && bloqueo { locked = true }
            if p == .active { Task { await store.refresh() } }
        }
        #if os(iOS)
        .backgroundTask(.appRefresh(Store.refreshTaskID)) {
            await Store.shared.refresh()
            Store.scheduleBackgroundRefresh()
        }
        #endif
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
        #endif
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        if store.hasToken {
            InboxView()
        } else {
            SetupView()
        }
    }
}
