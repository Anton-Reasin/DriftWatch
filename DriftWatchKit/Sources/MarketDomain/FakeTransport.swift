import SharedKit

/// A scripted market-data source for tests and offline demos.
///
/// You hand it a list of ticks up front; on `connect()` it replays them into
/// the event stream in order, then finishes. No network, fully deterministic,
/// so tests can assert exactly what comes out.
public actor FakeTransport: MarketTransport {
    private let ticks: [Tick]

    // Stream is created once at init and handed out as-is, so events() can be
    // nonisolated: reading the feed never waits on this actor.
    private nonisolated let stream: AsyncStream<TransportEvent>
    private nonisolated let continuation: AsyncStream<TransportEvent>.Continuation

    public init(ticks: [Tick]) {
        self.ticks = ticks
        (stream, continuation) = AsyncStream.makeStream()
    }

    public nonisolated func events() -> AsyncStream<TransportEvent> {
        stream
    }

    public func connect() async {
        for tick in ticks {
            continuation.yield(.tick(tick))
        }
        continuation.finish()
    }
}
