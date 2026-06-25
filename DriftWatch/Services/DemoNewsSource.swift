import Foundation

/// Bundled sample feed shown when no API key is set, so the news tab works on a
/// fresh clone. With a key, `NewsService` serves live news instead. The fixed
/// list is paged like the live source, so pagination is visible without a key.
struct DemoNewsSource: NewsSource {
    private let pageSize = 10

    func page(cursor: String?) async throws -> NewsPage {
        let start = Int(cursor ?? "0") ?? 0
        let end = min(start + pageSize, Self.items.count)
        let slice = start < end ? Array(Self.items[start..<end]) : []
        let nextCursor = end < Self.items.count ? String(end) : nil
        return NewsPage(items: slice, nextPage: nextCursor)
    }

    // Real crypto headlines pulled once from NewsData.io, kept as a static demo
    // feed. Images are dropped so the demo needs no network.
    private static let items: [NewsItem] = [
        NewsItem(id: "56131656773aeef31644f66cee0106a8", title: "Crypto Perpetual Futures See $981M in Liquidations as Longs Get Wiped Out", source: "Bitcoinworld.co.in", timeAgo: "12h ago", imageURL: nil, coins: ["ETH", "BTC"]),
        NewsItem(id: "bc8449f11fac9be9dfbadec8db5c5cd3", title: "Sonic Labs Suspends Annual Token Issuance, Is Working to Stop S Supply Inflation", source: "Coingecko", timeAgo: "12h ago", imageURL: nil, coins: []),
        NewsItem(id: "93c99da465373da7e7d082c190cdad9d", title: "GTA6 Pre-Orders Go Live at $80 With No Disc and Crypto Scammers Are Already Circling", source: "Brave New Coin", timeAgo: "12h ago", imageURL: nil, coins: ["NEAR", "BNB", "ETH"]),
        NewsItem(id: "d8f9193f78fbf8df8c41736b91b4a0d0", title: "Coinbase Secures MiCA License - Here Is Why It Matters", source: "Coinfomania", timeAgo: "12h ago", imageURL: nil, coins: ["UNI", "BTC", "JST"]),
        NewsItem(id: "b688e6edd8d8d2d4e93beddd442cddbd", title: "Memo Ochoa makes emotional appearance in 6th World Cup, but what is his crypto connection", source: "Coingecko", timeAgo: "12h ago", imageURL: nil, coins: ["ETH", "ONE", "JST"]),
        NewsItem(id: "cf2490c91f37c0470c704f84505e91f8", title: "Squid Launches QUID Token, Opens Public Sale on Kraken and Legion Starting June 30", source: "Nulltx", timeAgo: "12h ago", imageURL: nil, coins: ["CORE", "FORM", "ONE"]),
        NewsItem(id: "31a4ca1ed4ef39fc88fd0a64237a7e2d", title: "South Africa reaches World Cup knockout stage for first time as SAFA fan token enters the picture", source: "Coingecko", timeAgo: "12h ago", imageURL: nil, coins: ["CHZ", "FORM", "ONE"]),
        NewsItem(id: "a3cc7e0a16bf13ee6735d62676cb5819", title: "Crypto Whale Loses $14.1 Million After Four Liquidations on ETH Long Position", source: "Bitcoinworld.co.in", timeAgo: "12h ago", imageURL: nil, coins: ["ETH", "FORM"]),
        NewsItem(id: "98a6ce905b58ebb39208e4a5658a4db4", title: "Coinbase connects Solana validator to DoubleZero Edge for faster trading", source: "Coingecko", timeAgo: "12h ago", imageURL: nil, coins: ["JST"]),
        NewsItem(id: "5a42e44b2945cd68e2a1e96e302a470b", title: "Uniswap adds no-code token auction tool to its web app", source: "Coingecko", timeAgo: "12h ago", imageURL: nil, coins: ["ONE", "UNI", "FORM"]),
        NewsItem(id: "4d9e0e5be28d7003a75ad977237a282e", title: "Top 10 Biggest Bitcoin Crashes in History", source: "Coinpedia", timeAgo: "12h ago", imageURL: nil, coins: ["LINK", "CEL", "LUNA"]),
        NewsItem(id: "941d7c49781bf4eddc5682fb27173817", title: "Binance will support the Viction (VIC) network upgrade and hard fork on June 30", source: "Coingecko", timeAgo: "12h ago", imageURL: nil, coins: []),
        NewsItem(id: "72169e9ed6b4e5e3f51b7a0804d45fef", title: "Whale who previously shorted 16 altcoins suspected of selling 6,855 ETH", source: "Coingecko", timeAgo: "12h ago", imageURL: nil, coins: ["ETH"]),
        NewsItem(id: "0ea3a84d902e8dadd8f3bc322fc33d16", title: "South Korean Officials Meet SEC as Push for Unified Crypto Regulation Gains Momentum", source: "Crypto Economy", timeAgo: "12h ago", imageURL: nil, coins: ["MET", "ONE", "BTC"]),
        NewsItem(id: "4e9d2ce23b637df2e0396191e960eece", title: "Venice Token falls 11% - Why THIS level could decide VVV next move", source: "Ambcrypto", timeAgo: "12h ago", imageURL: nil, coins: ["FLOW", "NEAR"]),
        NewsItem(id: "01cd06976590b42340a8f95bb4596cbd", title: "Binance to Suspend Viction (VIC) Network Deposits and Withdrawals Ahead of Hard Fork", source: "Binance", timeAgo: "12h ago", imageURL: nil, coins: []),
        NewsItem(id: "b77447e41b9b23a33b5d0e101bc6c84a", title: "Dormant BAT ICO Whale Resurfaces, Sells $20.6 Million in Ethereum After Six Years", source: "Bitcoinworld.co.in", timeAgo: "12h ago", imageURL: nil, coins: ["ETH", "ONE", "BAT"]),
        NewsItem(id: "e18a661e9e474ceb6adc9c822eade515", title: "Funton.ai Partners with Echobit Exchange, Expanding Blockchain Gaming Experience", source: "Coingecko", timeAgo: "12h ago", imageURL: nil, coins: ["PEOPLE", "TON"]),
        NewsItem(id: "e696026073668645bb7c341a1bd50126", title: "Qualcomm Says Dragonfly C1000 CPU Will Launch in 2028", source: "Binance", timeAgo: "12h ago", imageURL: nil, coins: []),
        NewsItem(id: "a26cf25f76b080b6136ddfcd218d0312", title: "Uniswap Achieves Major Revenue Milestone as DEX Market Evolves", source: "Coinfomania", timeAgo: "12h ago", imageURL: nil, coins: ["UNI", "KEEP"]),
    ]
}
