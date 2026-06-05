/// A trading pair symbol such as `BTCUSDT`.
///
/// The raw value is stored uppercased so two symbols compare equal regardless
/// of how the caller typed them (`btcusdt` and `BTCUSDT` are the same pair).
public struct Symbol: Sendable, Hashable {
    /// Uppercased ticker, for example `BTCUSDT`.
    public let rawValue: String

    /// Creates a symbol, uppercasing the input so casing never affects equality.
    public init(_ rawValue: String) {
        self.rawValue = rawValue.uppercased()
    }

    /// Binance combined-stream name for the trade feed, for example `btcusdt@trade`.
    public var streamName: String {
        rawValue.lowercased() + "@trade"
    }
}
