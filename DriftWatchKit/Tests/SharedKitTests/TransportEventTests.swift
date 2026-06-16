import Foundation
import Testing

import SharedKit

@Suite("TransportEvent")
struct TransportEventTests {
    @Test("a tick event carries the tick it was given")
    func tickEventCarriesTick() {
        let tick = Tick(
            symbol: Symbol("BTCUSDT"),
            price: Decimal(string: "70000")!,
            time: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let event = TransportEvent.tick(tick)

        guard case let .tick(carried) = event else {
            Issue.record("expected a tick event")
            return
        }
        #expect(carried == tick)
    }

    @Test("a status event carries the status it was given")
    func statusEventCarriesStatus() {
        let event = TransportEvent.status(.live)

        guard case let .status(carried) = event else {
            Issue.record("expected a status event")
            return
        }
        #expect(carried == .live)
    }
}
