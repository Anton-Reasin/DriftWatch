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
    private(set) var priceHistory: [Decimal] = []
    private(set) var bandUpper: Decimal?
    private(set) var bandLower: Decimal?

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
            let upperID = UUID()
            let lowerID = UUID()
            @MainActor func arm(_ price: Decimal, _ symbol: Symbol) async {
                guard let band else { return }
                let upper = price * (1 + band)
                let lower = price * (1 - band)
                self?.bandUpper = upper
                self?.bandLower = lower
                await engine.add(
                    Rule(id: upperID, symbol: symbol, comparator: .greaterThan, threshold: upper))
                await engine.add(
                    Rule(id: lowerID, symbol: symbol, comparator: .lessThan, threshold: lower))
            }
            var armed = false
            for await event in source.events() {
                switch event {
                case .tick(let tick):
                    if !armed {
                        armed = true
                        await arm(tick.price, tick.symbol)
                    }
                    self?.record(tick.price)
                    let fired = await engine.ingest(tick)
                    for alert in fired {
                        self?.alerts.insert(alert, at: 0)
                    }
                    if !fired.isEmpty {
                        await arm(tick.price, tick.symbol)
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

    private var lastSampleAt: Date?

    private func record(_ price: Decimal) {
        latestPrice = price
        let now = Date()
        if let last = lastSampleAt, now.timeIntervalSince(last) < 0.5 {
            return
        }
        lastSampleAt = now
        priceHistory.append(price)
        if priceHistory.count > 120 {
            priceHistory.removeFirst()
        }
    }
}

extension MarketStore {
    static func live() -> MarketStore {
        return MarketStore(
            source: PriceSourceBinance(symbols: [Symbol("BTCUSDT")]),
            engine: RulesEngine(),
            band: Decimal(1) / Decimal(1000)  // 0.1%
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
