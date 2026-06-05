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

    /// Where the price came from: the live stream or a post-reconnect resync.
    public let source: TickSource

    // A public initializer is required because the compiler-generated memberwise
    // init is internal: consumers in the app target could not build a Tick across
    // the package boundary without it. The default keeps live ticks terse.
    public init(
        symbol: Symbol,
        price: Decimal,
        time: Date,
        source: TickSource = .stream
    ) {
        self.symbol = symbol
        self.price = price
        self.time = time
        self.source = source
    }
}
