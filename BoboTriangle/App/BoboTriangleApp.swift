import SwiftUI

@main
struct BoboTriangleApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var subscription = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(subscription)
        }
    }
}
