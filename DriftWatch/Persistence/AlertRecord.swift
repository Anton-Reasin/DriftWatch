import Foundation
import SwiftData

/// A fired alert saved to disk so the feed survives an app kill and restart.
///
/// The model mirrors the in-memory `AlertEvent` from the domain layer but stores
/// `price` as `Double` (SwiftData has no `Decimal` storage type) and keeps the
/// event fingerprint as the primary key for dedup.
@Model
final class AlertRecord {
    /// Stable fingerprint copied from `AlertEvent.eventID`. Unique so the same
    /// logical firing (re-detected after a reconnect replay) is stored once.
    @Attribute(.unique) var id: String

    /// Trading pair the alert is about, for example `BTCUSDT`.
    var symbol: String

    /// Price at the moment the rule fired.
    var price: Double

    /// When the rule fired. The feed is ordered by this, newest first.
    var firedAt: Date

    init(id: String, symbol: String, price: Double, firedAt: Date) {
        self.id = id
        self.symbol = symbol
        self.price = price
        self.firedAt = firedAt
    }
}
