import SwiftUI

/// Root container that splits the app into two tabs: the live price screen and
/// the news feed.
struct RootView: View {
    let store: MarketStore

    var body: some View {
        TabView {
            PriceView(store: store)
                .tabItem {
                    Label("Price", systemImage: "chart.line.uptrend.xyaxis")
                }

            NewsListView()
                .tabItem {
                    Label("News", systemImage: "newspaper.fill")
                }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView(store: .demo())
}
