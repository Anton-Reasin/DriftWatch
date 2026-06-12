/// Whether a rule is waiting or has already fired.
///
/// Like an alarm: `armed` is set and waiting, `triggered` has gone off. The
/// state stops a rule from firing on every tick while the price stays past
/// the threshold.
public enum RuleState: Sendable, Hashable {
    /// Set and waiting for the price to match.
    case armed

    /// Already fired.
    case triggered
}
