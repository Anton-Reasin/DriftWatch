import Foundation
import SharedKit

/// Drives a rules engine from a market-data transport.
///
/// Reads the transport's single event feed, hands each tick to the engine, and
/// republishes the alerts that fire as their own stream. It is the one consumer
/// of the transport feed (the feed is unicast), so it also reacts to connection
/// status: it marks a reconnect on the engine, then runs a REST resync once the
/// feed is live again.
public struct AlertService: Sendable {
    private let transport: any MarketTransport
    private let engine: RulesEngine
    private let resync: (any RestResyncClient)?
    private let symbols: [Symbol]
    private let now: @Sendable () -> Date

    public init(
        transport: any MarketTransport,
        engine: RulesEngine,
        resync: (any RestResyncClient)? = nil,
        symbols: [Symbol] = [],
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.engine = engine
        self.resync = resync
        self.symbols = symbols
        self.now = now
    }

    /// A stream of alerts produced by feeding the transport's ticks to the engine.
    ///
    /// On a reconnect the engine is marked, and on the following live status a
    /// resync runs per symbol. The resync runs in its own task, alongside the
    /// tick loop, so a live tick can reach the engine while the resync awaits -
    /// the race the engine's epoch guard is built for. The stream ends only once
    /// the feed ends and every pending resync has finished, so no alert is lost.
    public func alerts() -> AsyncStream<AlertEvent> {
        let transport = self.transport
        let engine = self.engine
        let resync = self.resync
        let symbols = self.symbols
        let now = self.now
        return AsyncStream { continuation in
            let task = Task {
                var pendingResyncs: [Task<Void, Never>] = []
                var awaitingRestore = false
                for await event in transport.events() {
                    switch event {
                    case .tick(let tick):
                        for alert in await engine.ingest(tick) {
                            continuation.yield(alert)
                        }
                    case .status(.reconnecting):
                        awaitingRestore = true
                        for symbol in symbols {
                            await engine.markReconnect(symbol)
                        }
                    case .status(.live):
                        guard awaitingRestore, let resync else { continue }
                        awaitingRestore = false
                        for symbol in symbols {
                            pendingResyncs.append(
                                Task {
                                    let alerts = await engine.resyncAfterReconnect(
                                        symbol, using: resync, at: now())
                                    for alert in alerts {
                                        continuation.yield(alert)
                                    }
                                }
                            )
                        }
                    case .status:
                        break
                    }
                }
                for resyncTask in pendingResyncs {
                    await resyncTask.value
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
