import Foundation
import Testing

import SharedKit
import MarketDomain

@Suite("FakeTransport")
struct FakeTransportTests {
    @Test("replays the scripted ticks in order")
    func replaysScriptedTicks() async {
        let first = Tick(
            symbol: Symbol("BTCUSDT"),
            price: Decimal(string: "70000")!,
            time: Date(timeIntervalSince1970: 1)
        )
        let second = Tick(
            symbol: Symbol("BTCUSDT"),
            price: Decimal(string: "70010")!,
            time: Date(timeIntervalSince1970: 2)
        )
        let transport = FakeTransport(ticks: [first, second])

        await transport.connect()

        var received: [Tick] = []
        for await event in transport.events() {
            if case let .tick(tick) = event {
                received.append(tick)
            }
        }

        #expect(received == [first, second])
    }
}
