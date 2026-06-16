import SharedKit

/// A scripted market-data source for tests and offline demos.
///
/// You hand it a list of ticks up front; on `connect()` it replays them into
/// the event stream in order, then finishes. No network, fully deterministic,
/// so tests can assert exactly what comes out.
///
/// It can also inject a reconnect: pass `dropConnectionAfter` to emit a
/// reconnecting-then-live pair after that many ticks, modelling a drop and its
/// restore. A drop scripted at `ticks.count` lands after the last tick. Simple
/// on purpose; real backoff and retries live in the live transport later.
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
        for (index, tick) in ticks.enumerated() {
            if index == dropConnectionAfter {
                yieldReconnect()
            }
            continuation.yield(.tick(tick))
        }
        // A drop scripted at ticks.count lands after the last tick, which lets a
        // test drive a resync with no live tick racing it.
        if dropConnectionAfter == ticks.count {
            yieldReconnect()
        }
        continuation.finish()
    }

    // Models a drop and its restore: the consumer marks the reconnect on the
    // first status and runs a resync on the second.
    private func yieldReconnect() {
        continuation.yield(.status(.reconnecting))
        continuation.yield(.status(.live))
    }
}
