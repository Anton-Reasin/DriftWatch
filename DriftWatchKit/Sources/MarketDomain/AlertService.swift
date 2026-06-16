import SharedKit

/// Drives a rules engine from a market-data transport.
///
/// Reads the transport's single event feed, hands each tick to the engine, and
/// republishes the alerts that fire as their own stream. It is the one consumer
/// of the transport feed (the feed is unicast), which is why reconnect and
/// REST-resync handling will live here too, in the next step.
public struct AlertService: Sendable {
    private let transport: any MarketTransport
    private let engine: RulesEngine

    public init(transport: any MarketTransport, engine: RulesEngine) {
        self.transport = transport
        self.engine = engine
    }

    /// A stream of alerts produced by feeding the transport's ticks to the engine.
    ///
    /// The stream ends when the transport feed ends. Cancelling the consumer
    /// stops the background reading through `onTermination`, so no socket or
    /// task is left running.
    public func alerts() -> AsyncStream<AlertEvent> {
        let transport = self.transport
        let engine = self.engine
        return AsyncStream { continuation in
            let task = Task {
                for await event in transport.events() {
                    guard case .tick(let tick) = event else { continue }
                    for alert in await engine.ingest(tick) {
                        continuation.yield(alert)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
