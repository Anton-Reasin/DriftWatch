import Foundation
import Testing

import SharedKit

@Suite("Tick")
struct TickTests {
    @Test("keeps the symbol, price and time it was created with")
    func storesItsValues() {
        let time = Date(timeIntervalSince1970: 1_700_000_000)
        let tick = Tick(
            symbol: Symbol("BTCUSDT"),
            price: Decimal(string: "70000.50")!,
            time: time
        )

        #expect(tick.symbol == Symbol("BTCUSDT"))
        #expect(tick.price == Decimal(string: "70000.50")!)
        #expect(tick.time == time)
    }

    @Test("adds large prices exactly, where Double would drift")
    func largePriceIsExact() {
        let almostHundredMillion = Decimal(string: "99999999.99")!
        let cent = Decimal(string: "0.01")!

        #expect(almostHundredMillion + cent == Decimal(string: "100000000.00")!)
    }

    @Test("keeps full precision for crypto-grade fractional prices")
    func manyDecimalPlacesAreExact() {
        let a = Decimal(string: "0.12345678")!
        let b = Decimal(string: "0.87654321")!

        #expect(a + b == Decimal(string: "0.99999999")!)
    }

    @Test("remembers its source and defaults to the live stream")
    func tracksSource() {
        let resynced = Tick(
            symbol: Symbol("BTCUSDT"),
            price: Decimal(string: "70000")!,
            time: Date(timeIntervalSince1970: 1_700_000_000),
            source: .restResync
        )
        #expect(resynced.source == .restResync)

        let live = Tick(
            symbol: Symbol("BTCUSDT"),
            price: Decimal(string: "70000")!,
            time: Date(timeIntervalSince1970: 1_700_000_000)
        )
        #expect(live.source == .stream)
    }
}
