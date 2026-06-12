import Foundation

/// How a price is compared against a rule's threshold.
public enum PriceComparator: Sendable, Hashable {
    case greaterThan
    case lessThan
    case greaterThanOrEqual
    case lessThanOrEqual

    /// Answers whether `price` satisfies this comparator against `threshold`.
    ///
    /// Decimal comparison is exact, so a price sitting right on the threshold
    /// resolves the same way every time: strict operators exclude it, the
    /// `orEqual` ones include it.
    public func matches(price: Decimal, threshold: Decimal) -> Bool {
        switch self {
        case .greaterThan: price > threshold
        case .lessThan: price < threshold
        case .greaterThanOrEqual: price >= threshold
        case .lessThanOrEqual: price <= threshold
        }
    }
}
