import Foundation
import Testing

import SharedKit

@Suite("PriceComparator")
struct PriceComparatorTests {
    private let threshold = Decimal(string: "70000")!

    @Test("greater-than matches only prices strictly above the threshold")
    func greaterThan() {
        let op = PriceComparator.greaterThan
        #expect(op.matches(price: Decimal(string: "70001")!, threshold: threshold))
        #expect(!op.matches(price: threshold, threshold: threshold))
        #expect(!op.matches(price: Decimal(string: "69999")!, threshold: threshold))
    }

    @Test("greater-than-or-equal includes the threshold itself")
    func greaterThanOrEqual() {
        let op = PriceComparator.greaterThanOrEqual
        #expect(op.matches(price: threshold, threshold: threshold))
        #expect(op.matches(price: Decimal(string: "70001")!, threshold: threshold))
        #expect(!op.matches(price: Decimal(string: "69999")!, threshold: threshold))
    }
}
