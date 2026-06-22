import Foundation
import SharedKit

public actor RulesEngine {
    private var rules: [UUID: Rule] = [:]

    // Per-symbol reconnect counter for the resync guard. Bumped on each
    // reconnect, snapshotted before the resync await, and re-checked after, so
    // a fetch begun for an older connection is recognised as stale.
    private var reconnectEpoch: [Symbol: UInt64] = [:]

    // Whether a live tick has arrived since the last reconnect, per symbol. A
    // live tick means fresh data already landed, so a resync in flight is stale.
    private var liveTickSeenSinceReconnect: [Symbol: Bool] = [:]

    public init() {}

    /// Registers a rule the engine matches incoming prices against.
    public func add(_ rule: Rule) {
        rules[rule.id] = rule
    }

    /// Matches a price against every armed rule and returns the alerts it fired.
    ///
    /// A rule fires at most once: on a match it flips to `.triggered` and stays
    /// quiet until re-armed, so a price sitting past the threshold does not ring
    /// on every tick. Returning the alerts instead of pushing them keeps this
    /// path pure and easy to test; forwarding them to the feed and UI is the
    /// app layer's job.
    public func ingest(_ tick: Tick) -> [AlertEvent] {
        // A live tick means we have fresh data, so any resync in flight is now
        // stale. Resync ticks do not set this: they must not beat a live tick.
        if tick.source == .stream {
            liveTickSeenSinceReconnect[tick.symbol] = true
        }
        var fired: [AlertEvent] = []
        for (id, rule) in rules where rule.state == .armed {
            guard rule.matches(tick) else { continue }
            rules[id]?.state = .triggered
            fired.append(
                AlertEvent(
                    ruleID: id,
                    symbol: tick.symbol,
                    price: tick.price,
                    firedAt: tick.time
                )
            )
        }
        return fired
    }

    /// Records that the feed for `symbol` reconnected.
    ///
    /// Bumps the reconnect epoch and clears the live-tick flag, so a resync that
    /// was started for an older connection can tell the world has moved on.
    public func markReconnect(_ symbol: Symbol) {
        reconnectEpoch[symbol, default: 0] += 1
        liveTickSeenSinceReconnect[symbol] = false
    }

    /// Refetches the last price after a reconnect and applies it, unless a live
    /// tick already arrived while the fetch was in flight.
    ///
    /// This is the one path that awaits, so it is the one place actor reentrancy
    /// can bite: the engine suspends at the fetch and another call (a live tick)
    /// can run before it resumes. The guard is to snapshot the epoch before the
    /// await and re-read state after it. A live tick always wins over a price
    /// that was already stale by the time it came back.
    public func resyncAfterReconnect(
        _ symbol: Symbol,
        using resync: any RestResyncClient,
        at time: Date
    ) async -> [AlertEvent] {
        let epoch = reconnectEpoch[symbol] ?? 0
        guard let price = try? await resync.lastPrice(symbol) else { return [] }
        // After the await the world may have changed: a newer reconnect, or a
        // live tick that already updated us. Either way the resync is stale.
        guard (reconnectEpoch[symbol] ?? 0) == epoch,
            liveTickSeenSinceReconnect[symbol] != true
        else { return [] }
        return ingest(Tick(symbol: symbol, price: price, time: time, source: .restResync))
    }
}
