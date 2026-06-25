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
    private let symbol: Symbol
    private let upperRuleID = UUID()
    private let lowerRuleID = UUID()
    private(set) var manualBounds = false
    private var armed = false
    private var dataStream: Task<Void, Never>?

    init(
        source: any PriceSource,
        engine: RulesEngine,
        rules: [Rule] = [],
        band: Decimal? = nil,
        symbol: Symbol = Symbol("BTCUSDT")
    ) {
        self.source = source
        self.engine = engine
        self.rules = rules
        self.band = band
        self.symbol = symbol
    }

    func start() {
        guard dataStream == nil else { return }
        let source = source
        let engine = engine
        let rules = rules
        dataStream = Task { [weak self] in
            for rule in rules {
                await engine.add(rule)
            }
            let producer = Task { await source.connect() }
            defer { producer.cancel() }
            for await event in source.events() {
                await self?.handle(event)
            }
        }
    }

    private func handle(_ event: TransportEvent) async {
        switch event {
        case .tick(let tick):
            if !armed, !manualBounds {
                armed = true
                await armBand(around: tick.price)
            }
            record(tick.price)
            let fired = await engine.ingest(tick)
            for alert in fired {
                alerts.insert(alert, at: 0)
            }
            if !fired.isEmpty, !manualBounds {
                await armBand(around: tick.price)
            }
        case .status(let status):
            connection = status
        }
    }

    private func armBand(around price: Decimal) async {
        guard let band else { return }
        let upper = price * (1 + band)
        let lower = price * (1 - band)
        bandUpper = upper
        bandLower = lower
        await engine.add(
            Rule(id: upperRuleID, symbol: symbol, comparator: .greaterThan, threshold: upper))
        await engine.add(
            Rule(id: lowerRuleID, symbol: symbol, comparator: .lessThan, threshold: lower))
    }

    /// Replaces the auto drift band with user-set alert lines.
    func setBounds(upper: Decimal, lower: Decimal) async {
        manualBounds = true
        bandUpper = upper
        bandLower = lower
        await engine.add(
            Rule(id: upperRuleID, symbol: symbol, comparator: .greaterThan, threshold: upper))
        await engine.add(
            Rule(id: lowerRuleID, symbol: symbol, comparator: .lessThan, threshold: lower))
    }

    /// Returns to the automatic band that re-anchors on each fire.
    func useAutoBounds() {
        manualBounds = false
        armed = false
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
