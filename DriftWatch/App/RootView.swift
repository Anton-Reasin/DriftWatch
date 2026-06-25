import SwiftData
import SwiftUI

import SharedKit

/// Root container that splits the app into three tabs: the live price screen,
/// the persisted alert history, and the news feed.
struct RootView: View {
    let store: MarketStore

    /// The app's on-disk SwiftData context, injected by `.modelContainer`.
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            PriceView(store: store)
                .tabItem {
                    Label("Price", systemImage: "chart.line.uptrend.xyaxis")
                }

            AlertHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            NewsListView()
                .tabItem {
                    Label("News", systemImage: "newspaper.fill")
                }
        }
        .preferredColorScheme(.dark)
        // Persist alerts as they fire. Watching the store from here keeps the
        // persistence concern out of MarketStore: when new alerts land we hand
        // each one to the history store, which dedupes by eventID.
        .onChange(of: store.alerts) { _, alerts in
            let history = AlertHistoryStore(context: modelContext)
            for alert in alerts {
                history.save(alert)
            }
        }
    }
}

#Preview {
    RootView(store: .demo())
        .modelContainer(for: AlertRecord.self, inMemory: true)
}
