import Foundation
import Observation

import MarketDomain
import SharedKit

@MainActor
@Observable
final class MarketStore {
    private(set) var latestPrice: Decimal?
    private(set) var alerts: [AlertEvent] = []
    private(set) var connection: ConnectionStatus = .connecting

    private let source: any PriceSource
    private let engine: RulesEngine
    private let rules: [Rule]
    private let band: Decimal?
    private var dataStream: Task<Void, Never>?

    init(
        source: any PriceSource,
        engine: RulesEngine,
        rules: [Rule] = [],
        band: Decimal? = nil
    ) {
        self.source = source
        self.engine = engine
        self.rules = rules
        self.band = band
    }

    func start() {
        guard dataStream == nil else { return }
        let source = source
        let engine = engine
        let rules = rules
        let band = band
        dataStream = Task { [weak self] in
            for rule in rules {
                await engine.add(rule)
            }
            let producer = Task { await source.connect() }
            defer { producer.cancel() }
            var bandArmed = false
            for await event in source.events() {
                switch event {
                case .tick(let tick):
                    if let band, !bandArmed {
                        bandArmed = true
                        let upper = tick.price * (1 + band)
                        let lower = tick.price * (1 - band)
                        await engine.add(
                            Rule(symbol: tick.symbol, comparator: .greaterThan, threshold: upper))
                        await engine.add(
                            Rule(symbol: tick.symbol, comparator: .lessThan, threshold: lower))
                    }
                    self?.latestPrice = tick.price
                    for alert in await engine.ingest(tick) {
                        self?.alerts.insert(alert, at: 0)
                    }
                case .status(let status):
                    self?.connection = status
                }
            }
        }
    }

    func stop() {
        dataStream?.cancel()
        dataStream = nil
    }
}

extension MarketStore {
    static func live() -> MarketStore {
        return MarketStore(
            source: PriceSourceBinance(symbols: [Symbol("BTCUSDT")]),
            engine: RulesEngine(),
            band: Decimal(5) / Decimal(10000)  // 0.05%
        )
    }

    static func demo() -> MarketStore {
        let symbol = Symbol("BTCUSDT")
        let now = Date()
        let ticks = [
            Tick(symbol: symbol, price: 60000, time: now),
            Tick(symbol: symbol, price: 60020, time: now),
            Tick(symbol: symbol, price: 60035, time: now),  // crosses the upper band
            Tick(symbol: symbol, price: 60080, time: now),
        ]
        let source = FakePriceSource(ticks: ticks, interval: .seconds(1))
        return MarketStore(
            source: source,
            engine: RulesEngine(),
            band: Decimal(5) / Decimal(10000)  // 0.05%
        )
    }
}
