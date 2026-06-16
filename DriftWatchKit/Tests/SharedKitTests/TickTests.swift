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

    @Test("carries the trade id when the stream provides one, nil otherwise")
    func tracksSequence() {
        let numbered = Tick(
            symbol: Symbol("BTCUSDT"),
            price: Decimal(string: "70000")!,
            time: Date(timeIntervalSince1970: 1_700_000_000),
            sequence: 412_345
        )
        #expect(numbered.sequence == 412_345)

        let resynced = Tick(
            symbol: Symbol("BTCUSDT"),
            price: Decimal(string: "70000")!,
            time: Date(timeIntervalSince1970: 1_700_000_000),
            source: .restResync
        )
        #expect(resynced.sequence == nil)
    }
}
