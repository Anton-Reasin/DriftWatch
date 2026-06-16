import Foundation
import Testing

import SharedKit
import MarketDomain

@Suite("AlertService")
struct AlertServiceTests {
    private func rule(_ threshold: String) -> Rule {
        Rule(
            symbol: Symbol("BTCUSDT"),
            comparator: .greaterThan,
            threshold: Decimal(string: threshold)!
        )
    }

    private func tick(_ price: String) -> Tick {
        Tick(
            symbol: Symbol("BTCUSDT"),
            price: Decimal(string: price)!,
            time: Date(timeIntervalSince1970: 1)
        )
    }

    private struct StubResyncClient: RestResyncClient {
        let price: Decimal
        func lastPrice(_ symbol: Symbol) async throws -> Decimal { price }
    }

    @Test("turns ticks that cross a rule into alerts")
    func bridgesCrossingTicksToAlerts() async {
        let engine = RulesEngine()
        await engine.add(rule("70000"))
        let transport = FakeTransport(ticks: [tick("69999"), tick("70001"), tick("70002")])
        let service = AlertService(transport: transport, engine: engine)

        let alerts = service.alerts()
        await transport.connect()

        var received: [AlertEvent] = []
        for await alert in alerts {
            received.append(alert)
        }

        #expect(received.count == 1)
        #expect(received.first?.price == Decimal(string: "70001")!)
    }

    @Test("emits nothing when no tick crosses a rule")
    func emitsNothingWithoutCrossing() async {
        let engine = RulesEngine()
        await engine.add(rule("70000"))
        let transport = FakeTransport(ticks: [tick("69998"), tick("69999")])
        let service = AlertService(transport: transport, engine: engine)

        let alerts = service.alerts()
        await transport.connect()

        var received: [AlertEvent] = []
        for await alert in alerts {
            received.append(alert)
        }

        #expect(received.isEmpty)
    }

    @Test("resyncs after a reconnect and fires on the recovered price")
    func resyncsAfterReconnect() async {
        let engine = RulesEngine()
        await engine.add(rule("70000"))
        // One tick below the line, then a drop and restore scripted at the end.
        // The recovered price sits above the line, so only the resync can fire.
        let transport = FakeTransport(ticks: [tick("69000")], dropConnectionAfter: 1)
        let resync = StubResyncClient(price: Decimal(string: "71000")!)
        let service = AlertService(
            transport: transport,
            engine: engine,
            resync: resync,
            symbols: [Symbol("BTCUSDT")],
            now: { Date(timeIntervalSince1970: 5) }
        )

        let alerts = service.alerts()
        await transport.connect()

        var received: [AlertEvent] = []
        for await alert in alerts {
            received.append(alert)
        }

        #expect(received.count == 1)
        #expect(received.first?.price == Decimal(string: "71000")!)
    }
}
