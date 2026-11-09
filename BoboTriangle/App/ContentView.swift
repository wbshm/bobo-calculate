import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var subscription: SubscriptionManager
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("font_size_level_ios_v1") private var fontSizeLevel = 2

    private var dynamicTypeSize: DynamicTypeSize {
        switch fontSizeLevel {
        case 0: .xSmall
        case 1: .small
        case 3: .large
        case 4: .xLarge
        case 5: .xxLarge
        case 6: .xxxLarge
        default: .medium
        }
    }

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack {
                TriangleCalculatorView()
            }
            .tabItem { Label(store.language.text("计算", "Calculate"), systemImage: "triangle") }
            .tag(0)

            if store.sceneEnabled {
                NavigationStack {
                    ScenesView()
                }
                .tabItem { Label(store.language.text("场景", "Tools"), systemImage: "wrench.and.screwdriver") }
                .tag(1)
            }

            NavigationStack(path: $store.morePath) {
                MoreView()
                    .navigationDestination(for: MoreRoute.self) { route in
                        switch route {
                        case .subscription:
                            SubscriptionView()
                        }
                    }
            }
            .tabItem { Label(store.language.text("更多", "More"), systemImage: "ellipsis.circle") }
            .tag(2)
        }
        .tint(.boboBlue)
        .dynamicTypeSize(dynamicTypeSize)
        .environment(\.locale, store.language.locale)
        .task { await subscription.start() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await subscription.refreshEntitlement() }
        }
        .onChange(of: store.sceneEnabled) { _, enabled in
            if !enabled, store.selectedTab == 1 { store.selectedTab = 2 }
        }
    }
}
