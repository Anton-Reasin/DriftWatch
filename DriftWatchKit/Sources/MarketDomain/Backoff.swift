import Foundation

/// Computes how long to wait before the next reconnect attempt.
public struct Backoff: Sendable {
    public let base: TimeInterval
    public let cap: TimeInterval

    public init(base: TimeInterval = 0.5, cap: TimeInterval = 30) {
        self.base = base
        self.cap = cap
    }

    func ceiling(for attempt: Int) -> TimeInterval {
        min(cap, base * pow(2, Double(attempt)))
    }

    public func delay(for attempt: Int) -> Duration {
        .seconds(ceiling(for: attempt) * Double.random(in: 0...1))
    }
}
