import Foundation
import Testing

import SharedKit
import MarketDomain

@Suite("RulesEngine")
struct RulesEngineTests {
    private func btcAbove(_ value: String) -> Rule {
        Rule(
            symbol: Symbol("BTCUSDT"),
            comparator: .greaterThan,
            threshold: Decimal(string: value)!
        )
    }

    private func tick(_ symbol: String, _ price: String) -> Tick {
        Tick(
            symbol: Symbol(symbol),
            price: Decimal(string: price)!,
            time: Date(timeIntervalSince1970: 1)
        )
    }

    @Test("fires one alert when an armed rule is crossed")
    func firesOnCrossing() async {
        let engine = RulesEngine()
        let rule = btcAbove("70000")
        await engine.add(rule)

        let alerts = await engine.ingest(tick("BTCUSDT", "70001"))

        #expect(alerts.count == 1)
        #expect(alerts.first?.ruleID == rule.id)
        #expect(alerts.first?.price == Decimal(string: "70001")!)
    }

    @Test("does not fire again while the rule stays triggered")
    func firesOnlyOnce() async {
        let engine = RulesEngine()
        await engine.add(btcAbove("70000"))

        _ = await engine.ingest(tick("BTCUSDT", "70001"))
        let second = await engine.ingest(tick("BTCUSDT", "70002"))

        #expect(second.isEmpty)
    }

    @Test("ignores a price that does not cross the threshold")
    func ignoresNonCrossing() async {
        let engine = RulesEngine()
        await engine.add(btcAbove("70000"))

        let alerts = await engine.ingest(tick("BTCUSDT", "69999"))

        #expect(alerts.isEmpty)
    }

    @Test("ignores ticks for a different symbol")
    func ignoresOtherSymbol() async {
        let engine = RulesEngine()
        await engine.add(btcAbove("70000"))

        let alerts = await engine.ingest(tick("ETHUSDT", "80000"))

        #expect(alerts.isEmpty)
    }
}
