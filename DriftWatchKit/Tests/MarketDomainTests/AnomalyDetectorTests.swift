import Foundation
import Testing

@testable import MarketDomain

@Suite("AnomalyDetector")
struct AnomalyDetectorTests {
    /// Feeds a list of prices in order and collects every anomaly that fired.
    private func feed(
        _ detector: AnomalyDetector,
        _ prices: [Double]
    ) async -> [AnomalyResult] {
        var fired: [AnomalyResult] = []
        for price in prices {
            if let result = await detector.ingest(price: price) {
                fired.append(result)
            }
        }
        return fired
    }

    /// A small, deterministic wobble around 100 so the baseline window has a tiny
    /// but non-zero variance. No randomness: the values repeat in a fixed cycle.
    private func wobble(count: Int) -> [Double] {
        let pattern: [Double] = [100.0, 100.1, 99.9, 100.05, 99.95]
        return (0..<count).map { pattern[$0 % pattern.count] }
    }

    @Test("a sudden spike fires an anomaly")
    func suddenSpikeFires() async {
        let detector = AnomalyDetector(windowSize: 20, zThreshold: 3.0, cooldownTicks: 5)

        // Warm the window with small moves, then jump the price hard.
        let baseline = wobble(count: 40)
        let warmupFires = await feed(detector, baseline)
        #expect(warmupFires.isEmpty)

        let spike = await detector.ingest(price: 130.0)
        #expect(spike != nil)
        #expect((spike?.zScore).map { abs($0) >= 3.0 } == true)
    }

    @Test("a steady trend does not fire")
    func steadyTrendDoesNotFire() async {
        let detector = AnomalyDetector(windowSize: 20, zThreshold: 3.0, cooldownTicks: 5)

        // Constant growth: every log-return is identical, so variance sits at the
        // floor and no single step can stand out.
        var price = 100.0
        var prices: [Double] = []
        for _ in 0..<80 {
            price *= 1.01
            prices.append(price)
        }

        let fired = await feed(detector, prices)
        #expect(fired.isEmpty)
    }

    @Test("no fire before the window is filled (warm-up)")
    func noFireDuringWarmup() async {
        let detector = AnomalyDetector(windowSize: 30, zThreshold: 3.0, cooldownTicks: 5)

        // A huge jump arrives while the window is still short: warm-up must
        // swallow it instead of firing on thin statistics.
        var prices = wobble(count: 5)
        prices.append(500.0)

        let fired = await feed(detector, prices)
        #expect(fired.isEmpty)
    }

    @Test("a dead-flat stream never fires and never crashes")
    func deadFlatNeverFires() async {
        let detector = AnomalyDetector(windowSize: 20, zThreshold: 3.0, cooldownTicks: 5)

        // Same price forever: every log-return is exactly zero, std-dev is zero.
        // The detector must guard the divide and stay silent.
        let flat = Array(repeating: 100.0, count: 60)
        let fired = await feed(detector, flat)
        #expect(fired.isEmpty)

        // Even a move after a long flat run stays quiet: variance is still zero.
        let afterFlat = await detector.ingest(price: 100.0)
        #expect(afterFlat == nil)
    }

    @Test("a spike fires once, not on every following tick (cooldown)")
    func spikeFiresOnceDuringCooldown() async {
        let cooldown = 5
        let detector = AnomalyDetector(windowSize: 20, zThreshold: 3.0, cooldownTicks: cooldown)

        _ = await feed(detector, wobble(count: 40))

        // One big jump, then several more equally large jumps right behind it.
        // Only the first should be reported; the rest fall inside the cooldown.
        var fired: [AnomalyResult] = []
        let spikePrices: [Double] = [130.0, 170.0, 220.0, 290.0]
        for price in spikePrices {
            if let result = await detector.ingest(price: price) {
                fired.append(result)
            }
        }

        #expect(fired.count == 1)
    }
}
