import Foundation
import Observation

/// Holds the news feed and pages through it as the user scrolls. Same shape as
/// the course model: loadFirstPage / loadNextPage / loadPage.
@MainActor
@Observable
final class NewsFeedStore {
    private(set) var items: [NewsItem] = []
    private(set) var isLoading = false
    private(set) var hasMore = true

    private var nextPage: String?
    private let service = NewsService()

    func loadFirstPage() async {
        nextPage = nil
        hasMore = true
        items.removeAll()
        await loadPage()
    }

    func loadNextPage() async {
        guard hasMore, !isLoading else { return }
        await loadPage()
    }

    private func loadPage() async {
        isLoading = true
        do {
            let page = try await service.page(cursor: nextPage)
            items.append(contentsOf: page.items)
            nextPage = page.nextPage
            hasMore = (page.nextPage != nil)
        } catch {
            print("News load failed: \(error)")
        }
        isLoading = false
    }
}
