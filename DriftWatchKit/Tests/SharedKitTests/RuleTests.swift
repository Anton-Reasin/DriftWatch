import Foundation
import Testing

import SharedKit

@Suite("Rule")
struct RuleTests {
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

    @Test("each rule gets its own id")
    func rulesHaveDistinctIDs() {
        #expect(btcAbove("70000").id != btcAbove("70000").id)
    }

    @Test("matches a tick that crosses the threshold")
    func matchesCrossingTick() {
        let rule = btcAbove("70000")
        #expect(rule.matches(tick("BTCUSDT", "70001")))
        #expect(!rule.matches(tick("BTCUSDT", "69999")))
    }

    @Test("ignores ticks for a different symbol")
    func ignoresOtherSymbols() {
        let rule = btcAbove("70000")
        #expect(!rule.matches(tick("ETHUSDT", "80000")))
    }
}
