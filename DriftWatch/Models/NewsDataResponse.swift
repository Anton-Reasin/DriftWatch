/// The whole answer from one NewsData.io request: a page of raw articles plus
/// the cursor for the next page.
struct NewsDataResponse: Decodable {
    let status: String
    let results: [NewsDataArticle]
    let nextPage: String?
}
