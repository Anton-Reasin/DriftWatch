/// Where a price observation came from.
///
/// After a reconnect the app refetches the last price over REST, which can
/// arrive slightly stale next to a fresh live tick. Tagging the source lets
/// the rules engine always prefer the live value over a stale resync.
public enum TickSource: Sendable, Hashable {
    /// Price delivered by the live market-data stream.
    case stream

    /// Price refetched over REST after a reconnect.
    case restResync
}
