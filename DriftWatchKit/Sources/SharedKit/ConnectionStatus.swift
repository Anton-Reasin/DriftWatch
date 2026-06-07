/// State of the connection to the market-data source.
///
/// Starts simple on purpose: four plain states are enough for the UI badge and
/// the first transport. Reconnect details (attempt count, delay, reason) come
/// later, when the real reconnect engine needs them.
public enum ConnectionStatus: Sendable, Hashable {
    /// Opening the connection, first time or after a drop.
    case connecting

    /// Connected, ticks are flowing.
    case live

    /// The connection dropped and is being restored.
    case reconnecting

    /// No connection, retries stopped.
    case offline
}
