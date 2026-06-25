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
    private(set) var ruleError: String?
    private(set) var ruleNotice: String?
    private(set) var textRules: [String] = []

    private let source: any PriceSource
    private let engine: RulesEngine
    private let rules: [Rule]
    private let band: Decimal?
    private let symbol: Symbol
    private let resync: (any RestResyncClient)?
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
        symbol: Symbol = Symbol("BTCUSDT"),
        resync: (any RestResyncClient)? = nil
    ) {
        self.source = source
        self.engine = engine
        self.rules = rules
        self.band = band
        self.symbol = symbol
        self.resync = resync
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
            // Dedup by eventID so the live feed matches History (which dedups on
            // the unique constraint) and ForEach never sees a duplicate id.
            for alert in fired where !alerts.contains(where: { $0.eventID == alert.eventID }) {
                alerts.insert(alert, at: 0)
            }
            if !fired.isEmpty, !manualBounds {
                await armBand(around: tick.price)
            }
        case .status(let status):
            connection = status
            await reactToStatus(status)
        }
    }

    private var awaitingRestore = false

    /// Drives the reconnect resync off the connection status. On a reconnect the
    /// engine is marked; once the feed is live again a REST resync runs in its own
    /// task, so a live tick can reach the engine while it awaits the price - the
    /// reentrancy race the engine's epoch guard is built for.
    private func reactToStatus(_ status: ConnectionStatus) async {
        switch status {
        case .reconnecting:
            awaitingRestore = true
            await engine.markReconnect(symbol)
        case .live where awaitingRestore:
            awaitingRestore = false
            guard let resync else { return }
            let engine = engine
            let symbol = symbol
            Task { [weak self] in
                let restored = await engine.resyncAfterReconnect(symbol, using: resync, at: Date())
                self?.applyAlerts(restored)
            }
        default:
            break
        }
    }

    private func applyAlerts(_ events: [AlertEvent]) {
        for alert in events where !alerts.contains(where: { $0.eventID == alert.eventID }) {
            alerts.insert(alert, at: 0)
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

    /// Parses a typed rule like "BTC > 70000" and arms it on the engine. The rule
    /// is applied to the watched symbol, since the app tracks a single pair.
    func addTextRule(_ text: String) async {
        ruleNotice = nil
        do {
            switch try parseRule(text) {
            case let .threshold(parsedSymbol, comparator, threshold):
                // The screen watches one pair. Accept the full symbol or a short
                // ticker prefix (BTC for BTCUSDT); reject a different coin instead
                // of silently arming it on the watched pair.
                guard symbol.rawValue.hasPrefix(parsedSymbol.rawValue) else {
                    ruleError = "This screen watches \(symbol.rawValue)"
                    return
                }
                guard !textRules.contains(text) else {
                    ruleError = nil
                    return
                }
                await engine.add(
                    Rule(symbol: symbol, comparator: comparator, threshold: threshold))
                textRules.insert(text, at: 0)
                ruleError = nil
            case .percentMove:
                // Parsed fine, but the engine has no window matcher yet. Show it as
                // a neutral note, not an error.
                ruleError = nil
                ruleNotice = "Percent-move parses, matching is on the roadmap"
            }
        } catch let error as RuleDSLError {
            ruleError = Self.describe(error)
        } catch {
            ruleError = "Invalid rule"
        }
    }

    private static func describe(_ error: RuleDSLError) -> String {
        switch error {
        case .emptyInput: "Type a rule, like BTC > 70000"
        case .missingOperator: "Add a comparator: >, <, >=, <="
        case .missingSymbol: "Start with a symbol, like BTC"
        case .notANumber(let value): "Not a number: \(value)"
        case .windowOutOfRange(let minutes): "Window \(minutes)m out of range (1-1440)"
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
            band: Decimal(1) / Decimal(1000),  // 0.1%
            resync: BinanceRestResyncClient()
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
