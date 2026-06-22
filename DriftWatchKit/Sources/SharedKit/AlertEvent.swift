import Foundation

/// A record that a rule fired: which rule, on what symbol, at what price and when.
///
/// Emitted by the engine on a match, then carried to the UI and the feed.
public struct AlertEvent: Sendable, Hashable {
    /// Stable fingerprint built from the rule and a time interval, not the raw
    /// timestamp. The same logical firing re-detected moments later (say, after
    /// a reconnect replays the crossing tick) lands in the same time interval and
    /// gets the same id, so the feed can recognise it and not store it twice. A
    /// raw timestamp would only match on a bit-identical Date, which never
    /// happens twice in practice.
    public let eventID: String

    /// The rule that fired.
    public let ruleID: UUID

    /// The pair the alert is about.
    public let symbol: Symbol

    /// Price at the moment the rule fired.
    public let price: Decimal

    /// When the rule fired.
    public let firedAt: Date

    // intervalSeconds is also the dedup granularity: one rule can produce at
    // most one feed entry per time interval. 60s is a starting default, revisit
    // when re-arm behavior is settled.
    public init(
        ruleID: UUID,
        symbol: Symbol,
        price: Decimal,
        firedAt: Date,
        intervalSeconds: Int = 60
    ) {
        self.ruleID = ruleID
        self.symbol = symbol
        self.price = price
        self.firedAt = firedAt
        let timeInterval = Int(firedAt.timeIntervalSince1970.rounded(.down)) / max(1, intervalSeconds)
        self.eventID = "\(ruleID.uuidString)-\(timeInterval)"
    }
}
