import Foundation

/// Everything a market-data source emits, carried over one channel.
///
/// One stream of events keeps the consumer simple: it reads a single feed and
/// switches on the case to tell a price from a status change.
///
/// There is no resync case on purpose: refetching the last price after a
/// reconnect is the rules engine's job (that is where the stale-price guard
/// lives), so the transport only reports ticks and status changes. A resynced
/// price enters the engine as a `Tick` tagged `.restResync`.
public enum TransportEvent: Sendable {
    /// A new price arrived from the live stream.
    case tick(Tick)

    /// The connection status changed.
    case status(ConnectionStatus)
}
