/// One raw article exactly as NewsData.io returns it. Swift decodes it from the
/// server's JSON, then we map it to the app's `NewsItem`.
struct NewsDataArticle: Decodable {
    let articleId: String
    let title: String
    let sourceName: String?
    let pubDate: String?
    let imageUrl: String?
    let coin: [String]?
}
