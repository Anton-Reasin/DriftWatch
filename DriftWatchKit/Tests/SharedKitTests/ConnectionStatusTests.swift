import Testing

import SharedKit

@Suite("ConnectionStatus")
struct ConnectionStatusTests {
    @Test("different states are distinct")
    func statesAreDistinct() {
        #expect(ConnectionStatus.live != ConnectionStatus.offline)
        #expect(ConnectionStatus.connecting != ConnectionStatus.reconnecting)
    }

    @Test("the same state compares equal")
    func sameStateIsEqual() {
        #expect(ConnectionStatus.live == ConnectionStatus.live)
    }
}
