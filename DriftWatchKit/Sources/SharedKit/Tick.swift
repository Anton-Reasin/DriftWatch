import Foundation

/// A single price observation for a symbol at a point in time.
///
/// Price is a `Decimal` so money keeps exact precision: comparing against a
/// threshold must not drift the way binary floating point does.
public struct Tick: Sendable, Hashable {
    /// The trading pair this price belongs to.
    public let symbol: Symbol

    /// Exact price at the moment of the observation.
    public let price: Decimal

    /// When the observation happened.
    public let time: Date

    public init(symbol: Symbol, price: Decimal, time: Date) {
        self.symbol = symbol
        self.price = price
        self.time = time
    }
}
