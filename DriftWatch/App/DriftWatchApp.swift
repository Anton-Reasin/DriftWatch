import SwiftData
import SwiftUI

@main
struct DriftWatchApp: App {
    @State private var store = MarketStore.live()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
        // On-disk store for the alert history feed. Fired alerts are saved here
        // and read back by AlertHistoryView, so the feed survives kill+restart.
        .modelContainer(for: AlertRecord.self)
    }
}
