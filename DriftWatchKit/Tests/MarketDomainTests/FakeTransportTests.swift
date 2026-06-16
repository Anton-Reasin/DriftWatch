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

    @Test("injects a reconnecting-then-live pair after the given number of ticks")
    func injectsReconnect() async {
        let ticks = (1...3).map { i in
            Tick(
                symbol: Symbol("BTCUSDT"),
                price: Decimal(i),
                time: Date(timeIntervalSince1970: TimeInterval(i))
            )
        }
        let transport = FakeTransport(ticks: ticks, dropConnectionAfter: 2)

        await transport.connect()

        var kinds: [String] = []
        for await event in transport.events() {
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
