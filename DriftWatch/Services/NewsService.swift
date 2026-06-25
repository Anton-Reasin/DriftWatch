import Foundation

/// Why a news request could not be made.
enum NewsError: LocalizedError {
    /// No NewsData.io key was found in Secrets.plist.
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "No NewsData.io key. Copy Secrets.example.plist to Secrets.plist and add your key."
        }
    }
}

/// Loads crypto news from NewsData.io, one page at a time via the API cursor.
struct NewsService {
    // Read from a gitignored Secrets.plist so the key stays out of the repo.
    // See Secrets.example.plist and the README for setup.
    private let apiKey = AppSecrets.newsDataAPIKey
    private let endpoint = "https://newsdata.io/api/1/crypto"

    /// Fetches one page. Pass `nil` for the first page, or the previous page's
    /// cursor to get the next one.
    func page(cursor: String?) async throws -> NewsPage {
        guard let apiKey else { throw NewsError.missingAPIKey }
        guard var components = URLComponents(string: endpoint) else {
            throw URLError(.badURL)
        }
        var query = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "language", value: "en"),
        ]
        if let cursor {
            query.append(URLQueryItem(name: "page", value: cursor))
        }
        components.queryItems = query
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(NewsDataResponse.self, from: data)
        let items = response.results.map { article in
            NewsItem(
                id: article.articleId,
                title: article.title,
                source: article.sourceName ?? "Unknown",
                timeAgo: article.pubDate ?? "",
                imageURL: article.imageUrl.flatMap { URL(string: $0) },
                coins: article.coin ?? []
            )
        }
        return NewsPage(items: items, nextPage: response.nextPage)
    }
}
