import Foundation
import SharedKit

/// The heart of the app: holds the user's rules and decides when a price fires one.
///
/// All mutable state lives inside this actor, so there is no data race by
/// construction: only the actor touches `rules`, one call at a time. The hot
/// path `ingest` is synchronous on purpose (no await): an actor only lets
/// another call in at a suspension point, so a path without one cannot be
/// interrupted half-way. The one path that must await - refetching the last
/// price over REST after a reconnect - comes later and is handled with care.
public actor RulesEngine {
    private var rules: [UUID: Rule] = [:]

    public init() {}

    /// Registers a rule the engine matches incoming prices against.
    public func add(_ rule: Rule) {
        rules[rule.id] = rule
    }

    /// Matches a price against every armed rule and returns the alerts it fired.
    ///
    /// A rule fires at most once: on a match it flips to `.triggered` and stays
    /// quiet until re-armed, so a price sitting past the threshold does not ring
    /// on every tick. Returning the alerts instead of pushing them keeps this
    /// path pure and easy to test; forwarding them to the feed and UI is the
    /// app layer's job.
    public func ingest(_ tick: Tick) -> [AlertEvent] {
        var fired: [AlertEvent] = []
        for (id, rule) in rules where rule.state == .armed {
            guard rule.matches(tick) else { continue }
            rules[id]?.state = .triggered
            fired.append(
                AlertEvent(
                    ruleID: id,
                    symbol: tick.symbol,
                    price: tick.price,
                    firedAt: tick.time
                )
            )
        }
        return fired
    }
}
