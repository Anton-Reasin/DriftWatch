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
    private(set) var loadFailed = false
    private(set) var statusMessage: String?

    private var nextPage: String?
    private var seenIDs = Set<String>()
    private let service = NewsService()

    func loadFirstPage() async {
        guard !isLoading else { return }
        nextPage = nil
        hasMore = true
        loadFailed = false
        statusMessage = nil
        items.removeAll()
        seenIDs.removeAll()
        await loadPage()
    }

    func loadNextPage() async {
        guard hasMore, !isLoading, !loadFailed else { return }
        await loadPage()
    }

    private func loadPage() async {
        isLoading = true
        do {
            let page = try await service.page(cursor: nextPage)
            // Drop articles already shown: NewsData can repeat one across pages,
            // and a duplicate id breaks the List's ForEach.
            let fresh = page.items.filter { seenIDs.insert($0.id).inserted }
            items.append(contentsOf: fresh)
            nextPage = page.nextPage
            hasMore = (page.nextPage != nil)
            loadFailed = false
            statusMessage = nil
        } catch {
            loadFailed = true
            statusMessage = error.localizedDescription
            print("❌ News load failed: \(error)")
        }
        isLoading = false
    }
}
