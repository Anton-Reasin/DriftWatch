import SharedKit

/// A source of market data: the live exchange or a fake used in tests.
///
/// Both sides of the app depend on this port, not on a concrete source, so the
/// transport can be swapped in one line. Kept minimal on purpose; more methods
/// (disconnect, subscribe) are added when a conformer actually needs them.
public protocol MarketTransport: Sendable {
    /// The feed of events (ticks, status changes) the consumer reads.
    ///
    /// `nonisolated` because the stream is created once and handed out as-is;
    /// reading it must not wait on the transport's actor (see concurrency rule).
    nonisolated func events() -> AsyncStream<TransportEvent>

    /// Opens the connection.
    func connect() async
}
