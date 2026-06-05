import Testing

import SharedKit

@Suite("TickSource")
struct TickSourceTests {
    @Test("live stream and REST resync are distinct cases")
    func casesAreDistinct() {
        #expect(TickSource.stream != TickSource.restResync)
    }

    @Test("same case compares equal")
    func sameCaseIsEqual() {
        #expect(TickSource.stream == TickSource.stream)
    }
}
