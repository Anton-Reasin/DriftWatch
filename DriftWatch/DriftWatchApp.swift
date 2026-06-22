import SwiftUI

@main
struct DriftWatchApp: App {
    @State private var store = MarketStore.live()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
