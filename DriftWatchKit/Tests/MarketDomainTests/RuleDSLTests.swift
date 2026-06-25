import Foundation
import Testing

import SharedKit
import MarketDomain

@Suite("RuleDSL")
struct RuleDSLTests {
    // MARK: - Positive: threshold

    struct ThresholdCase: Sendable {
        let text: String
        let symbol: String
        let comparator: PriceComparator
        let threshold: String
    }

    @Test(
        "parses threshold rules",
        arguments: [
            ThresholdCase(text: "BTC > 70000", symbol: "BTC", comparator: .greaterThan, threshold: "70000"),
            ThresholdCase(text: "BTC < 60000", symbol: "BTC", comparator: .lessThan, threshold: "60000"),
            ThresholdCase(text: "ethusdt >= 3500.5", symbol: "ETHUSDT", comparator: .greaterThanOrEqual, threshold: "3500.5"),
            ThresholdCase(text: "  SOL   <=   140  ", symbol: "SOL", comparator: .lessThanOrEqual, threshold: "140"),
        ]
    )
    func parsesThreshold(_ testCase: ThresholdCase) throws {
        let spec = try parseRule(testCase.text)
        guard case let .threshold(symbol, comparator, threshold) = spec else {
            Issue.record("expected a threshold spec for \(testCase.text)")
            return
        }
        #expect(symbol == Symbol(testCase.symbol))
        #expect(comparator == testCase.comparator)
        #expect(threshold == Decimal(string: testCase.threshold))
    }

    @Test("threshold spec maps onto a Rule")
    func thresholdMapsToRule() throws {
        let spec = try parseRule("BTC > 70000")
        let rule = try #require(spec.makeRule())
        #expect(rule.symbol == Symbol("BTC"))
        #expect(rule.comparator == .greaterThan)
        #expect(rule.threshold == Decimal(string: "70000"))
        #expect(rule.state == .armed)
    }

    // MARK: - Positive: percent move

    struct PercentCase: Sendable {
        let text: String
        let symbol: String
        let percent: String
        let window: Int
    }

    @Test(
        "parses percent-move rules",
        arguments: [
            PercentCase(text: "ETH %5 in 10m", symbol: "ETH", percent: "5", window: 10),
            PercentCase(text: "BTC %2.5 in 1m", symbol: "BTC", percent: "2.5", window: 1),
            PercentCase(text: "  sol  % 12  in  1440m  ", symbol: "SOL", percent: "12", window: 1440),
            PercentCase(text: "DOGE %0.5 IN 60M", symbol: "DOGE", percent: "0.5", window: 60),
        ]
    )
    func parsesPercentMove(_ testCase: PercentCase) throws {
        let spec = try parseRule(testCase.text)
        guard case let .percentMove(symbol, percent, window) = spec else {
            Issue.record("expected a percent-move spec for \(testCase.text)")
            return
        }
        #expect(symbol == Symbol(testCase.symbol))
        #expect(percent == Decimal(string: testCase.percent))
        #expect(window.minutes == testCase.window)
    }

    @Test("percent-move spec has no Rule mapping yet")
    func percentMoveHasNoRule() throws {
        let spec = try parseRule("ETH %5 in 10m")
        #expect(spec.makeRule() == nil)
    }

    // MARK: - Negative: required cases

    @Test("empty input throws emptyInput")
    func emptyInputThrows() {
        #expect(throws: RuleDSLError.emptyInput) {
            try parseRule("")
        }
        #expect(throws: RuleDSLError.emptyInput) {
            try parseRule("    \n  ")
        }
    }

    @Test("no operator throws missingOperator")
    func missingOperatorThrows() {
        #expect(throws: RuleDSLError.missingOperator) {
            try parseRule("BTC 70000")
        }
    }

    @Test("non-numeric threshold throws notANumber")
    func notANumberThrows() throws {
        let error = try captureError { try parseRule("BTC > abc") }
        guard case let .notANumber(text) = error else {
            Issue.record("expected notANumber, got \(error)")
            return
        }
        #expect(text == "abc")
    }

    @Test(
        "window out of range throws windowOutOfRange",
        arguments: [
            "ETH %5 in 0m",
            "ETH %5 in 5000m",
        ]
    )
    func windowOutOfRangeThrows(_ text: String) throws {
        let error = try captureError { try parseRule(text) }
        guard case .windowOutOfRange = error else {
            Issue.record("expected windowOutOfRange, got \(error)")
            return
        }
    }

    @Test("non-numeric percent throws notANumber")
    func percentNotANumberThrows() throws {
        let error = try captureError { try parseRule("ETH %x in 10m") }
        guard case let .notANumber(text) = error else {
            Issue.record("expected notANumber, got \(error)")
            return
        }
        #expect(text == "x")
    }

    // MARK: - Helpers

    // Runs `body`, returns the RuleDSLError it threw, or records an issue and
    // rethrows anything that is not a RuleDSLError. Lets a test inspect the
    // associated value of an error case, which `#expect(throws:)` alone cannot.
    private func captureError(
        _ body: () throws -> RuleSpec
    ) throws -> RuleDSLError {
        do {
            let spec = try body()
            Issue.record("expected a thrown RuleDSLError, got \(spec)")
            throw RuleDSLError.emptyInput
        } catch let error as RuleDSLError {
            return error
        }
    }
}
