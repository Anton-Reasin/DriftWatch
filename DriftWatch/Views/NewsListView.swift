import SwiftUI

/// The news feed: a dark, scrollable list of news cards. Sample data for now;
/// real API data and pagination come later.
struct NewsListView: View {
    private let items = NewsItem.sampleFeed

    var body: some View {
        List(items) { item in
            NewsRow(item: item)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .preferredColorScheme(.dark)
    }
}

extension NewsItem {
    /// Real crypto headlines pulled once from the API, used while the UI is
    /// built. Replaced by live data later.
    static let sampleFeed: [NewsItem] = [
        NewsItem(
            id: "s1",
            title: "Bitcoin Looks More Like a Tech Proxy Than a Digital Gold Hedge",
            source: "Investing",
            timeAgo: "1h ago",
            imageURL: nil,
            coins: ["BTC", "XRP"]
        ),
        NewsItem(
            id: "s2",
            title: "CryptoQuant says Strategy should pause bitcoin purchases and rebuild cash reserves",
            source: "The Block",
            timeAgo: "2h ago",
            imageURL: nil,
            coins: ["BTC", "BGB"]
        ),
        NewsItem(
            id: "s3",
            title: "Sui News: Cumberland, Fluid, and SwissBorg join institutional coalition on Hashi",
            source: "CryptoPotato",
            timeAgo: "3h ago",
            imageURL: nil,
            coins: ["SUI", "CORE"]
        ),
        NewsItem(
            id: "s4",
            title: "Ethereum Price Forecast: EF cuts 20% of workforce, reduces annual spend by 40%",
            source: "FXStreet",
            timeAgo: "4h ago",
            imageURL: nil,
            coins: ["ETH", "NEAR"]
        ),
        NewsItem(
            id: "s5",
            title: "Ethereum Foundation shifts gears with major budget cuts",
            source: "Bitcoinhaber",
            timeAgo: "5h ago",
            imageURL: nil,
            coins: ["ETH", "CORE"]
        ),
        NewsItem(
            id: "s6",
            title: "Best altcoin to buy as capital rotates away from Bitcoin ETFs",
            source: "TechBullion",
            timeAgo: "6h ago",
            imageURL: nil,
            coins: ["ETH", "PEPE"]
        ),
        NewsItem(
            id: "s7",
            title: "Fed rate hike odds for December jump amid strong payroll data",
            source: "Crypto Briefing",
            timeAgo: "7h ago",
            imageURL: nil,
            coins: ["ONE"]
        ),
        NewsItem(
            id: "s8",
            title: "US stocks close lower: Nasdaq leads decline amid broad market weakness",
            source: "BitcoinWorld",
            timeAgo: "8h ago",
            imageURL: nil,
            coins: ["NEAR", "ONE"]
        ),
        NewsItem(
            id: "s9",
            title: "Polymarket prices 96% chance Micron beats earnings Wednesday",
            source: "CoinGecko",
            timeAgo: "9h ago",
            imageURL: nil,
            coins: ["NEAR", "ONE"]
        ),
        NewsItem(
            id: "s10",
            title: "Claude outage hit public users while Claude for Government stayed online",
            source: "Binance",
            timeAgo: "10h ago",
            imageURL: nil,
            coins: ["SNT"]
        ),
    ]
}

#Preview {
    NewsListView()
}
