import Foundation
import SharedKit

/// Fetches the last price over Binance's public REST endpoint, used to catch up
/// after a reconnect. No API key required.
///
/// REST returns no trade id, which is exactly why the engine guards a stale
/// resync with a reconnect epoch instead of a sequence number.
public struct BinanceRestResyncClient: RestResyncClient {
    private let session: URLSession
    private let host: String

    public init(
        session: URLSession = .shared,
        host: String = "https://data-api.binance.vision"
    ) {
        self.session = session
        self.host = host
    }

    public func lastPrice(_ symbol: Symbol) async throws -> Decimal {
        guard var components = URLComponents(string: host + "/api/v3/ticker/price") else {
            throw URLError(.badURL)
        }
        components.queryItems = [URLQueryItem(name: "symbol", value: symbol.rawValue)]
        guard let url = components.url else { throw URLError(.badURL) }

        let (data, _) = try await session.data(from: url)
        let payload = try JSONDecoder().decode(TickerPrice.self, from: data)
        guard let price = Decimal(string: payload.price) else {
            throw URLError(.cannotParseResponse)
        }
        return price
    }

    private struct TickerPrice: Decodable {
        let price: String
    }
}
