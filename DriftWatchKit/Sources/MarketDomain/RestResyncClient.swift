import Foundation
import SharedKit

/// Fetches the current price of a symbol over a one-shot request, used to catch
/// up after a reconnect.
///
/// The engine depends on this port, not on networking, so tests inject a fake
/// and the live client wraps the Binance REST endpoint. A resync price carries
/// no trade id (REST does not return one), which is the reason the engine
/// guards a stale resync with a reconnect epoch instead of a sequence number.
public protocol RestResyncClient: Sendable {
    /// Returns the last traded price for `symbol`.
    ///
    /// - Parameter symbol: The pair to fetch.
    /// - Returns: The latest price as an exact `Decimal`.
    /// - Throws: If the price cannot be fetched (network or decoding failure).
    func lastPrice(_ symbol: Symbol) async throws -> Decimal
}
