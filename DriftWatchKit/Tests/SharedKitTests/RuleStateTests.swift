import Testing

import SharedKit

@Suite("RuleState")
struct RuleStateTests {
    @Test("armed and triggered are distinct states")
    func statesAreDistinct() {
        #expect(RuleState.armed != RuleState.triggered)
    }

    @Test("the same state compares equal")
    func sameStateIsEqual() {
        #expect(RuleState.armed == RuleState.armed)
    }
}
