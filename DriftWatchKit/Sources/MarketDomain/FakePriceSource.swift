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
/// on purpose; real backoff and retries live in the live source later.
///
/// Unlike the live source, this one finishes its stream when the script
/// runs out - that is the "source is done for good" case from the port's
/// contract, and it is what lets a test's `for await` loop end on its own.
public actor FakePriceSource: PriceSource {
    private let ticks: [Tick]
    private let dropConnectionAfter: Int?
    private let interval: Duration

    // Stream is created once at init and handed out as-is, so events() can be
    // nonisolated: reading the feed never waits on this actor.
    private nonisolated let stream: AsyncStream<TransportEvent>
    private nonisolated let continuation: AsyncStream<TransportEvent>.Continuation

    // interval paces the replay so a demo price visibly ticks. Tests leave it at
    // zero, which keeps the replay instant and deterministic.
    public init(ticks: [Tick], dropConnectionAfter: Int? = nil, interval: Duration = .zero) {
        self.ticks = ticks
        self.dropConnectionAfter = dropConnectionAfter
        self.interval = interval
        (stream, continuation) = AsyncStream.makeStream()
    }

    public nonisolated func events() -> AsyncStream<TransportEvent> {
        stream
    }

    public func connect() async {
        for (index, tick) in ticks.enumerated() {
            if Task.isCancelled { break }
            if index == dropConnectionAfter {
                yieldReconnect()
            }
            continuation.yield(.tick(tick))
            if interval > .zero {
                try? await Task.sleep(for: interval)
            }
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
