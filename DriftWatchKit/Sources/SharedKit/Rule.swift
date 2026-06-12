import Foundation

/// A price alert the user set: watch a symbol, fire when the price meets a
/// threshold under a comparator.
public struct Rule: Sendable, Hashable, Identifiable {
    /// Unique id, generated per rule so the engine and feed can tell them apart.
    public let id: UUID

    /// The pair this rule watches.
    public let symbol: Symbol

    /// How the price is compared to the threshold.
    public let comparator: PriceComparator

    /// The price level the rule reacts to.
    public let threshold: Decimal

    /// Whether the rule is armed or has already fired.
    public var state: RuleState

    // id and state have defaults for new rules; both can be supplied when a rule
    // is rebuilt from storage. Public init is needed across the package boundary.
    public init(
        id: UUID = UUID(),
        symbol: Symbol,
        comparator: PriceComparator,
        threshold: Decimal,
        state: RuleState = .armed
    ) {
        self.id = id
        self.symbol = symbol
        self.comparator = comparator
        self.threshold = threshold
        self.state = state
    }

    /// Whether `tick` satisfies this rule: same symbol and the comparator matches.
    ///
    /// Does not change `state`; arming and triggering is the engine's job.
    public func matches(_ tick: Tick) -> Bool {
        guard tick.symbol == symbol else { return false }
        return comparator.matches(price: tick.price, threshold: threshold)
    }
}
