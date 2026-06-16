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

    /// Trade id from the exchange, when the stream provides one.
    ///
    /// The Binance @trade stream numbers every trade, so the engine can drop a
    /// tick whose sequence is not above the last seen one: that is what catches
    /// duplicates and reordering after a reconnect. A REST resync price has no
    /// trade id, hence the optional.
    public let sequence: UInt64?

    /// Where the price came from: the live stream or a post-reconnect resync.
    public let source: TickSource

    // A public initializer is required because the compiler-generated memberwise
    // init is internal: consumers in the app target could not build a Tick across
    // the package boundary without it. The defaults keep live ticks terse.
    public init(
        symbol: Symbol,
        price: Decimal,
        time: Date,
        sequence: UInt64? = nil,
        source: TickSource = .stream
    ) {
        self.symbol = symbol
        self.price = price
        self.time = time
        self.sequence = sequence
        self.source = source
    }
}
