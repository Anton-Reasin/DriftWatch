import Foundation

/// Everything a market-data source emits, carried over one channel.
///
/// One stream of events keeps the consumer simple: it reads a single feed and
/// switches on the case to tell a price from a status change.
public enum TransportEvent: Sendable {
    /// A new price arrived from the live stream.
    case tick(Tick)

    /// The connection status changed.
    case status(ConnectionStatus)

    /// A price was refetched over REST after a reconnect.
    case resynced(Symbol, Decimal)
}
