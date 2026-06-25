import Foundation

/// One news item shown in the feed. The store builds these from API data and
/// the views render them.
struct NewsItem: Identifiable {
    let id: String
    let title: String
    let source: String
    let timeAgo: String
    let imageURL: URL?
    let coins: [String]
}
