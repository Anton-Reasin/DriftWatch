import Foundation
import Testing

import SharedKit

@Suite("AlertEvent")
struct AlertEventTests {
    private let ruleID = UUID()
    private let time = Date(timeIntervalSince1970: 1_700_000_000)

    private func event(at time: Date) -> AlertEvent {
        AlertEvent(
            ruleID: ruleID,
            symbol: Symbol("BTCUSDT"),
            price: Decimal(string: "70000.50")!,
            firedAt: time
        )
    }

    @Test("keeps the rule, symbol, price and time it fired with")
    func storesItsValues() {
        let alert = event(at: time)
        #expect(alert.ruleID == ruleID)
        #expect(alert.symbol == Symbol("BTCUSDT"))
        #expect(alert.price == Decimal(string: "70000.50")!)
        #expect(alert.firedAt == time)
    }

    // The dedup property that matters: a firing re-detected a few seconds later
    // (reconnect replays the crossing tick) must map to the SAME id, so the
    // feed's unique constraint can drop it. Base time 1_700_000_000 sits 20s
    // into its minute bucket: +30s stays inside, +61s crosses into the next.
    @Test("firings within one bucket share the eventID, the next bucket does not")
    func eventIDBucketsTime() {
        #expect(event(at: time).eventID == event(at: time).eventID)
        #expect(event(at: time).eventID == event(at: time.addingTimeInterval(30)).eventID)
        #expect(event(at: time).eventID != event(at: time.addingTimeInterval(61)).eventID)
    }

    @Test("different rules never share an eventID, even in the same bucket")
    func eventIDSeparatesRules() {
        let other = AlertEvent(
            ruleID: UUID(),
            symbol: Symbol("BTCUSDT"),
            price: Decimal(string: "70000.50")!,
            firedAt: time
        )
        #expect(event(at: time).eventID != other.eventID)
    }
}
