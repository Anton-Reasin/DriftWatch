import Foundation
import RegexBuilder
import SharedKit

/// A rule the user typed as text, after parsing but before it becomes a `Rule`.
///
/// Two shapes the DSL understands:
/// - a price threshold, like `BTC > 70000`, which maps straight onto `Rule`;
/// - a percent move over a window, like `ETH %5 in 10m`, which `Rule` has no
///   field for yet, so it stays a spec the engine layer can grow into.
public enum RuleSpec: Sendable, Hashable {
    /// Fire when the price crosses `threshold` under `comparator`.
    case threshold(symbol: Symbol, comparator: PriceComparator, threshold: Decimal)

    /// Fire when the price moves `percent` (absolute, in percent points) inside
    /// a `window` of minutes.
    case percentMove(symbol: Symbol, percent: Decimal, window: WindowMinutes)
}

extension RuleSpec {
    /// Turns a threshold spec into a `Rule` the engine can match ticks against.
    ///
    /// Only the threshold shape has a `Rule` today: percent move needs a window
    /// the current `Rule` does not carry, so it returns nil rather than fake a
    /// threshold. The caller decides what to do with a percent-move spec.
    public func makeRule(id: UUID = UUID(), state: RuleState = .armed) -> Rule? {
        switch self {
        case let .threshold(symbol, comparator, threshold):
            Rule(
                id: id,
                symbol: symbol,
                comparator: comparator,
                threshold: threshold,
                state: state
            )
        case .percentMove:
            nil
        }
    }
}

/// A percent-move window in whole minutes, kept inside a sane range.
///
/// A window must be at least 1 minute and no more than a day: shorter is noise,
/// longer stops being a short-term move alert. Out-of-range input is rejected at
/// parse time, so by the time a value exists it is already valid.
public struct WindowMinutes: Sendable, Hashable {
    /// Smallest accepted window, in minutes.
    public static let minimum = 1

    /// Largest accepted window, in minutes (24 hours).
    public static let maximum = 1_440

    /// The window length in minutes, guaranteed within `minimum...maximum`.
    public let minutes: Int

    /// Creates a window, rejecting anything outside `minimum...maximum`.
    ///
    /// - Throws: `RuleDSLError.windowOutOfRange` when `minutes` is too small or
    ///   too large.
    public init(_ minutes: Int) throws {
        guard (Self.minimum...Self.maximum).contains(minutes) else {
            throw RuleDSLError.windowOutOfRange(minutes)
        }
        self.minutes = minutes
    }
}

/// Why a piece of rule text could not be parsed.
///
/// Each case points at one concrete failure so the UI can say what is wrong
/// instead of a blanket "invalid rule".
public enum RuleDSLError: Error, Sendable, Hashable {
    /// The text was empty or only whitespace.
    case emptyInput

    /// No comparator (`>`, `<`, `>=`, `<=`) and no percent marker (`%`) was found.
    case missingOperator

    /// A symbol was expected at the start but the text did not begin with one.
    case missingSymbol

    /// The threshold or percent part was present but not a number. Carries the
    /// offending text.
    case notANumber(String)

    /// The window minutes parsed but fell outside the allowed range. Carries the
    /// value that was rejected.
    case windowOutOfRange(Int)
}

/// Parses a single line of rule text into a `RuleSpec`.
///
/// Grammar (case-insensitive, surrounding spaces ignored):
/// - threshold: `<SYMBOL> <op> <number>`, op is `>`, `<`, `>=`, `<=`
/// - percent move: `<SYMBOL> %<number> in <minutes>m`
///
/// - Parameter text: the raw line a user typed.
/// - Returns: the parsed `RuleSpec`.
/// - Throws: a `RuleDSLError` naming the first thing that is wrong.
public func parseRule(_ text: String) throws -> RuleSpec {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw RuleDSLError.emptyInput }

    // Percent move is tried first: its `%` marker is unambiguous, so a line that
    // has one is never a threshold.
    // A comparator means a threshold rule; route to percent-move only when there
    // is no comparator but a percent marker is present.
    if trimmed.contains(where: { "<>".contains($0) }) {
        return try parseThreshold(trimmed)
    }
    if trimmed.contains("%") {
        return try parsePercentMove(trimmed)
    }
    return try parseThreshold(trimmed)
}

// MARK: - Threshold

private func parseThreshold(_ text: String) throws -> RuleSpec {
    // A bare symbol with no comparator is the "missing operator" case; surface it
    // before the full match so the error is specific rather than a generic miss.
    guard text.contains(where: { "<>".contains($0) }) else {
        throw RuleDSLError.missingOperator
    }

    // References are created per call: `Reference` is not Sendable, so it cannot
    // live as a module global under strict concurrency.
    let symbolReference = Reference(Substring.self)
    let comparatorReference = Reference(Substring.self)
    let numberReference = Reference(Substring.self)

    let pattern = Regex {
        Anchor.startOfSubject
        ZeroOrMore(.whitespace)
        Capture(as: symbolReference) {
            OneOrMore(.word)
        }
        ZeroOrMore(.whitespace)
        Capture(as: comparatorReference) {
            ChoiceOf {
                ">="
                "<="
                ">"
                "<"
            }
        }
        ZeroOrMore(.whitespace)
        Capture(as: numberReference) {
            OneOrMore(.anyOf("0123456789."))
        }
        ZeroOrMore(.whitespace)
        Anchor.endOfSubject
    }

    guard let match = try pattern.wholeMatch(in: text) else {
        // Reaching here means a comparator exists but the surrounding shape is
        // off: most often the threshold side is not a clean number.
        throw RuleDSLError.notANumber(thresholdTail(of: text))
    }

    let symbol = Symbol(String(match[symbolReference]))
    let comparator = try comparator(from: String(match[comparatorReference]))
    let numberText = String(match[numberReference])
    guard isCleanNumber(numberText), let threshold = Decimal(string: numberText),
        threshold.isFinite
    else {
        throw RuleDSLError.notANumber(numberText)
    }

    return .threshold(symbol: symbol, comparator: comparator, threshold: threshold)
}

private func comparator(from token: String) throws -> PriceComparator {
    switch token {
    case ">": .greaterThan
    case "<": .lessThan
    case ">=": .greaterThanOrEqual
    case "<=": .lessThanOrEqual
    default: throw RuleDSLError.missingOperator
    }
}

// A number must have at most one decimal point and at least one digit, so "1.2.3"
// and "." are rejected instead of silently truncating in Decimal(string:).
private func isCleanNumber(_ text: String) -> Bool {
    text.filter { $0 == "." }.count <= 1 && text.contains(where: \.isNumber)
}

// Best-effort grab of whatever sits after the comparator, so a `notANumber`
// error can quote the offending text instead of an empty string.
private func thresholdTail(of text: String) -> String {
    guard let index = text.lastIndex(where: { "<>=".contains($0) }) else { return text }
    let tail = text[text.index(after: index)...]
    return tail.trimmingCharacters(in: .whitespaces)
}

// MARK: - Percent move

private func parsePercentMove(_ text: String) throws -> RuleSpec {
    // Per-call references for the same Sendable reason as in parseThreshold.
    let symbolReference = Reference(Substring.self)
    let percentReference = Reference(Substring.self)
    let windowReference = Reference(Substring.self)

    let pattern = Regex {
        Anchor.startOfSubject
        ZeroOrMore(.whitespace)
        Capture(as: symbolReference) {
            OneOrMore(.word)
        }
        ZeroOrMore(.whitespace)
        "%"
        ZeroOrMore(.whitespace)
        Capture(as: percentReference) {
            OneOrMore(.anyOf("0123456789."))
        }
        ZeroOrMore(.whitespace)
        "in"
        ZeroOrMore(.whitespace)
        Capture(as: windowReference) {
            OneOrMore(.digit)
        }
        ZeroOrMore(.whitespace)
        "m"
        ZeroOrMore(.whitespace)
        Anchor.endOfSubject
    }
    .ignoresCase()

    guard let match = try pattern.wholeMatch(in: text) else {
        // The `%` was there but the rest did not line up. Without a leading
        // symbol it is a missing-symbol error; otherwise the percent value is
        // the thing that is not a number.
        if !startsWithSymbol(text) {
            throw RuleDSLError.missingSymbol
        }
        throw RuleDSLError.notANumber(percentTail(of: text))
    }

    let symbol = Symbol(String(match[symbolReference]))
    let percentText = String(match[percentReference])
    guard isCleanNumber(percentText), let percent = Decimal(string: percentText),
        percent.isFinite
    else {
        throw RuleDSLError.notANumber(percentText)
    }

    let windowText = String(match[windowReference])
    guard let rawWindow = Int(windowText) else {
        throw RuleDSLError.notANumber(windowText)
    }
    let window = try WindowMinutes(rawWindow)

    return .percentMove(symbol: symbol, percent: percent, window: window)
}

// Does the text begin with a word-character run before the `%`? Used only to
// pick the right error when a percent line fails to match.
private func startsWithSymbol(_ text: String) -> Bool {
    let head = Regex {
        Anchor.startOfSubject
        ZeroOrMore(.whitespace)
        OneOrMore(.word)
    }
    return (try? head.firstMatch(in: text)) != nil
}

// Whatever sits between `%` and `in`, for a precise notANumber message.
private func percentTail(of text: String) -> String {
    guard let percentIndex = text.firstIndex(of: "%") else { return text }
    let after = text[text.index(after: percentIndex)...]
    if let inRange = after.range(of: " in ") {
        return after[..<inRange.lowerBound].trimmingCharacters(in: .whitespaces)
    }
    return after.trimmingCharacters(in: .whitespaces)
}
