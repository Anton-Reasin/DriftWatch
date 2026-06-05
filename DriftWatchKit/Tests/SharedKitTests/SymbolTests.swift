import Testing

import SharedKit

@Suite("Symbol")
struct SymbolTests {
    @Test("uppercases the raw value on init")
    func uppercasesRawValue() {
        #expect(Symbol("btcusdt").rawValue == "BTCUSDT")
    }

    @Test("treats different input casing as the same symbol")
    func equatesIgnoringCase() {
        #expect(Symbol("btcusdt") == Symbol("BTCUSDT"))
    }

    @Test("builds the Binance trade stream name")
    func buildsStreamName() {
        #expect(Symbol("BTCUSDT").streamName == "btcusdt@trade")
    }
}
