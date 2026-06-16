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
    ///
    /// Contract: exactly ONE consumer per transport. AsyncStream is unicast,
    /// not broadcast - with two readers each event goes to only one of them,
    /// so anyone else who needs the data (UI badge, persistence) gets it from
    /// that single consumer, not from a second `for await` here.
    ///
    /// Contract: a connection drop does NOT end the stream; it arrives as a
    /// `.status` event and ticks resume after the reconnect. The stream
    /// finishes only when the transport is done for good (disconnected or,
    /// for a scripted fake, out of script).
    nonisolated func events() -> AsyncStream<TransportEvent>

    /// Opens the connection.
    func connect() async
}
