import Foundation

/// What the detector reports when a price move stands out from recent history.
///
/// Carried up to the UI the same way an `AlertEvent` is: a value type that
/// crosses the actor boundary, so it must be `Sendable`. The z-score is kept so
/// the UI can show how far out the move was, not just that it happened.
public struct AnomalyResult: Sendable, Hashable {
    /// The price that triggered the anomaly.
    public let price: Double

    /// Log-return of this price against the previous one.
    public let logReturn: Double

    /// How many standard deviations the return sat from the rolling mean. Signed,
    /// so the caller can tell a spike up from a spike down.
    public let zScore: Double

    public init(price: Double, logReturn: Double, zScore: Double) {
        self.price = price
        self.logReturn = logReturn
        self.zScore = zScore
    }
}

/// Flags price moves that are statistically unusual for the recent stream.
///
/// The idea is plain: most ticks nudge the price a little, a real event jolts it.
/// The detector keeps a sliding window of log-returns, and when a fresh return
/// sits more than `zThreshold` standard deviations from the window's mean it
/// fires. Log-returns rather than raw deltas so the measure is scale-free: a 1%
/// move on a 30000 coin and on a 2 coin look the same to the model.
///
/// It is an `actor` because the window is mutable shared state and live ticks may
/// arrive from any task. Every method here is synchronous (no `await` inside), so
/// there is no reentrancy window to guard.
public actor AnomalyDetector {
    // MARK: - Configuration

    /// How many recent log-returns the rolling statistics are computed over.
    private let windowSize: Int

    /// Fire when `|z|` is at or above this many standard deviations.
    private let zThreshold: Double

    /// Ticks to stay quiet after a fire, so one spike does not ring on every
    /// follow-up tick while the window still carries the jolt.
    private let cooldownTicks: Int

    /// Below this standard deviation the stream is treated as flat: returns are
    /// all but identical, so a z-score would blow up on a meaningless denominator.
    /// Guards both the divide-by-zero and the false alarm on a dead-flat feed.
    private let varianceFloor: Double

    // MARK: - State

    /// Sliding window of the most recent log-returns, oldest first.
    private var returns: [Double] = []

    /// Last price seen, needed to form the next log-return. `nil` until the first
    /// tick, since a return needs two prices.
    private var lastPrice: Double?

    /// Ticks left to suppress after the last fire. Counts down to zero.
    private var cooldownRemaining = 0

    // MARK: - Init

    /// Creates a detector.
    ///
    /// - Parameters:
    ///   - windowSize: number of recent returns the statistics use. Must be at
    ///     least 2 for a variance to exist; smaller values are clamped up.
    ///   - zThreshold: how many standard deviations out a move must be to fire.
    ///   - cooldownTicks: ticks to stay silent after a fire.
    ///   - varianceFloor: standard deviations at or below this count as flat.
    public init(
        windowSize: Int = 30,
        zThreshold: Double = 3.0,
        cooldownTicks: Int = 5,
        varianceFloor: Double = 1e-9
    ) {
        self.windowSize = max(2, windowSize)
        self.zThreshold = zThreshold
        self.cooldownTicks = max(0, cooldownTicks)
        self.varianceFloor = max(0, varianceFloor)
    }

    // MARK: - Ingest

    /// Feeds one price in and reports an anomaly if this move stands out.
    ///
    /// Returns `nil` during warm-up (window not yet full), on a flat or
    /// zero-variance stream, while cooling down after a recent fire, or simply
    /// when the move is ordinary. A non-`nil` result means `|z|` met the
    /// threshold on a healthy window.
    ///
    /// - Parameter price: the latest price. Non-positive or non-finite prices are
    ///   ignored (a log-return needs a positive ratio), and they do not disturb
    ///   the window.
    /// - Returns: the anomaly, or `nil`.
    public func ingest(price: Double) -> AnomalyResult? {
        guard price.isFinite, price > 0 else { return nil }

        guard let previous = lastPrice else {
            // First valid price: nothing to compare against yet.
            lastPrice = price
            return nil
        }
        lastPrice = price

        let logReturn = log(price / previous)
        guard logReturn.isFinite else { return nil }

        // Decide using the window as it stands BEFORE adding this return, so the
        // fresh move is scored against history, not against itself.
        let result = evaluate(price: price, logReturn: logReturn)

        append(logReturn)

        if cooldownRemaining > 0 {
            cooldownRemaining -= 1
            return nil
        }

        if let result {
            cooldownRemaining = cooldownTicks
            return result
        }
        return nil
    }

    // MARK: - Helpers

    /// Scores `logReturn` against the current window. Returns the anomaly when it
    /// is far enough out, or `nil` during warm-up or on a flat window.
    private func evaluate(price: Double, logReturn: Double) -> AnomalyResult? {
        // Warm-up: no verdict until the window is full, so early statistics built
        // from a handful of points cannot raise a false alarm.
        guard returns.count >= windowSize else { return nil }

        let mean = returns.reduce(0, +) / Double(returns.count)
        let variance =
            returns.reduce(0) { sum, value in
                let delta = value - mean
                return sum + delta * delta
            } / Double(returns.count)
        let stdDev = variance.squareRoot()

        // Flat / zero-variance stream: denominator is meaningless, so never fire
        // and never divide by it.
        guard stdDev > varianceFloor else { return nil }

        let zScore = (logReturn - mean) / stdDev
        guard abs(zScore) >= zThreshold else { return nil }

        return AnomalyResult(price: price, logReturn: logReturn, zScore: zScore)
    }

    /// Pushes a return into the window, dropping the oldest once it is full.
    private func append(_ logReturn: Double) {
        returns.append(logReturn)
        if returns.count > windowSize {
            returns.removeFirst()
        }
    }
}
