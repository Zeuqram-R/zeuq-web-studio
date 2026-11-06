import SwiftUI

@main
struct ZeuqApp: App {
    @StateObject private var store = Store.shared
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Color("AccentColor"))
                .onAppear { Store.requestNotifications() }
        }
        .onChange(of: phase) { _, p in
            #if os(iOS)
            if p == .background { Store.scheduleBackgroundRefresh() }
            #endif
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
