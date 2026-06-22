import Foundation
import Testing

import SharedKit
import MarketDomain

@Suite("FakePriceSource")
struct FakePriceSourceTests {
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
        let source = FakePriceSource(ticks: [first, second])

        await source.connect()

        var received: [Tick] = []
        for await event in source.events() {
            if case let .tick(tick) = event {
                received.append(tick)
            }
        }

        #expect(received == [first, second])
    }

    @Test("injects a reconnecting-then-live pair after the given number of ticks")
    func injectsReconnect() async {
        let ticks = (1...3).map { i in
            Tick(
                symbol: Symbol("BTCUSDT"),
                price: Decimal(i),
                time: Date(timeIntervalSince1970: TimeInterval(i))
            )
        }
        let source = FakePriceSource(ticks: ticks, dropConnectionAfter: 2)

        await source.connect()

        var kinds: [String] = []
        for await event in source.events() {
            switch event {
            case .tick: kinds.append("tick")
            case .status(.reconnecting): kinds.append("reconnecting")
            case .status(.live): kinds.append("live")
            default: kinds.append("other")
            }
        }

        #expect(kinds == ["tick", "tick", "reconnecting", "live", "tick"])
    }
}
