import SharedKit

/// A scripted market-data source for tests and offline demos.
///
/// You hand it a list of ticks up front; on `connect()` it replays them into
/// the event stream in order, then finishes. No network, fully deterministic,
/// so tests can assert exactly what comes out.
///
/// It can also inject chaos: pass `dropConnectionAfter` to emit a reconnect
/// status mid-stream, which lets tests check the feed survives a drop. This is
/// a simple model on purpose; real backoff and retries live in the live
/// transport later.
///
/// Unlike the live transport, this one finishes its stream when the script
/// runs out - that is the "transport is done for good" case from the port's
/// contract, and it is what lets a test's `for await` loop end on its own.
public actor FakeTransport: MarketTransport {
    private let ticks: [Tick]
    private let dropConnectionAfter: Int?

    // Stream is created once at init and handed out as-is, so events() can be
    // nonisolated: reading the feed never waits on this actor.
    private nonisolated let stream: AsyncStream<TransportEvent>
    private nonisolated let continuation: AsyncStream<TransportEvent>.Continuation

    public init(ticks: [Tick], dropConnectionAfter: Int? = nil) {
        self.ticks = ticks
        self.dropConnectionAfter = dropConnectionAfter
        (stream, continuation) = AsyncStream.makeStream()
    }

    public nonisolated func events() -> AsyncStream<TransportEvent> {
        stream
    }

    public func connect() async {
        var delivered = 0
        for tick in ticks {
            if delivered == dropConnectionAfter {
                continuation.yield(.status(.reconnecting))
            }
            continuation.yield(.tick(tick))
            delivered += 1
        }
        continuation.finish()
    }
}
