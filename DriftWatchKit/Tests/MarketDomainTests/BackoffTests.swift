import Foundation
import Testing

@testable import MarketDomain

@Suite("Backoff")
struct BackoffTests {
    @Test("ceiling doubles each attempt and stops at the cap")
    func ceilingGrowsAndCaps() {
        let backoff = Backoff(base: 0.5, cap: 30)
        #expect(backoff.ceiling(for: 0) == 0.5)
        #expect(backoff.ceiling(for: 1) == 1)
        #expect(backoff.ceiling(for: 2) == 2)
        #expect(backoff.ceiling(for: 5) == 16)
        #expect(backoff.ceiling(for: 6) == 30)  // 0.5 * 64 = 32, capped to 30
        #expect(backoff.ceiling(for: 100) == 30)
    }

    @Test("delay never goes below zero or above the attempt ceiling")
    func delayStaysWithinRange() {
        let backoff = Backoff(base: 0.5, cap: 30)
        for attempt in 0...10 {
            let ceiling = Duration.seconds(backoff.ceiling(for: attempt))
            let delay = backoff.delay(for: attempt)
            #expect(delay >= .zero)
            #expect(delay <= ceiling)
        }
    }
}
