import Foundation
import Testing

import SharedKit
import MarketDomain

@Suite("RulesEngine resync")
struct RulesEngineResyncTests {
    private let btc = Symbol("BTCUSDT")
    private let resyncTime = Date(timeIntervalSince1970: 3)

    private func rule(_ threshold: String) -> Rule {
        Rule(symbol: btc, comparator: .greaterThan, threshold: Decimal(string: threshold)!)
    }

    private func liveTick(_ price: String) -> Tick {
        Tick(
            symbol: btc,
            price: Decimal(string: price)!,
            time: Date(timeIntervalSince1970: 2),
            source: .stream
        )
    }

    /// A resync client that returns a fixed price after running a hook. The hook
    /// is where a test injects a live tick, reproducing the exact race: a fresh
    /// tick reaches the engine while it is suspended waiting for the REST price.
    private struct HookResyncClient: RestResyncClient {
        let price: Decimal
        let duringAwait: @Sendable () async -> Void
        func lastPrice(_ symbol: Symbol) async throws -> Decimal {
            await duringAwait()
            return price
        }
    }

    private struct PlainResyncClient: RestResyncClient {
        let price: Decimal
        func lastPrice(_ symbol: Symbol) async throws -> Decimal { price }
    }

    /// Collects alerts produced inside a Sendable hook (a plain var cannot be
    /// captured mutably by a @Sendable closure).
    private actor Collector {
        private(set) var alerts: [AlertEvent] = []
        func record(_ produced: [AlertEvent]) { alerts += produced }
    }

    @Test("applies the resync price when no live tick arrived during the await")
    func appliesResyncWhenUncontended() async {
        let engine = RulesEngine()
        await engine.add(rule("70000"))
        await engine.markReconnect(btc)
        let resync = PlainResyncClient(price: Decimal(string: "71000")!)

        let alerts = await engine.resyncAfterReconnect(btc, using: resync, at: resyncTime)

        #expect(alerts.count == 1)
        #expect(alerts.first?.price == Decimal(string: "71000")!)
    }

    @Test("drops a stale resync when a live tick arrived during the await")
    func dropsStaleResyncOnReentrantLiveTick() async {
        let engine = RulesEngine()
        await engine.add(rule("70000"))
        await engine.markReconnect(btc)
        // Live tick sits below the threshold, so the only thing that could fire
        // is the stale resync price. A wrong answer here is a false alert.
        let live = liveTick("69000")
        let resync = HookResyncClient(price: Decimal(string: "71000")!) {
            _ = await engine.ingest(live)
        }

        let alerts = await engine.resyncAfterReconnect(btc, using: resync, at: resyncTime)

        #expect(alerts.isEmpty)
    }

    @Test("a live tick during the await fires once and the resync adds no duplicate")
    func liveTickWinsAndFiresOnce() async {
        let engine = RulesEngine()
        await engine.add(rule("70000"))
        await engine.markReconnect(btc)
        // Live tick crosses, and the stale resync would also cross. Only the live
        // tick may fire; the resync must not add a second alert.
        let live = liveTick("71000")
        let collector = Collector()
        let resync = HookResyncClient(price: Decimal(string: "72000")!) {
            await collector.record(engine.ingest(live))
        }

        let resyncAlerts = await engine.resyncAfterReconnect(btc, using: resync, at: resyncTime)

        #expect(await collector.alerts.count == 1)
        #expect(resyncAlerts.isEmpty)
    }
}
