/// One page of the news feed: the items on this page plus the cursor that asks
/// the server for the next page.
struct NewsPage {
    let items: [NewsItem]
    let nextPage: String?
}
