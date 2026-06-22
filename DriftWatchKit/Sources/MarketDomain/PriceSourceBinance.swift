import Foundation

import SharedKit

public actor PriceSourceBinance: PriceSource {
    private let symbols: [Symbol]
    private let session: URLSession
    private var task: URLSessionWebSocketTask?

    private nonisolated let stream: AsyncStream<TransportEvent>
    private nonisolated let continuation: AsyncStream<TransportEvent>.Continuation

    public init(symbols: [Symbol], session: URLSession = .shared) {
        self.symbols = symbols
        self.session = session
        (stream, continuation) = AsyncStream.makeStream()
    }

    public nonisolated func events() -> AsyncStream<TransportEvent> {
        stream
    }

    public func connect() async {
        let streamPath = symbols.map(\.streamName).joined(separator: "/")
        var components = URLComponents(string: "wss://data-stream.binance.vision/stream")!
        components.queryItems = [URLQueryItem(name: "streams", value: streamPath)]
        guard let url = components.url else { return }

        let task = session.webSocketTask(with: url)
        self.task = task
        continuation.yield(.status(.connecting))
        task.resume()
        await receiveLoop(on: task)
    }

    private func receiveLoop(on task: URLSessionWebSocketTask) async {
        var announcedLive = false
        while true {
            guard let message = try? await task.receive() else {
                continuation.yield(.status(.offline))
                return
            }
            if case .string(let text) = message, let tick = Self.makeTick(from: text) {
                if !announcedLive {
                    announcedLive = true
                    continuation.yield(.status(.live))
                }
                continuation.yield(.tick(tick))
            }
        }
    }

    private nonisolated static func makeTick(from text: String) -> Tick? {
        guard let data = text.data(using: .utf8) else { return nil }
        guard let frame = try? JSONDecoder().decode(Frame.self, from: data) else { return nil }
        guard let price = Decimal(string: frame.data.p) else { return nil }
        return Tick(
            symbol: Symbol(frame.data.s),
            price: price,
            time: Date(timeIntervalSince1970: Double(frame.data.E) / 1000),
            sequence: frame.data.t,
            source: .stream
        )
    }

    private struct Trade: Decodable {
        let s: String  // symbol
        let p: String  // price, sent as a string to stay exact
        let t: UInt64  // trade id
        let E: UInt64  // event time in milliseconds
    }

    private struct Frame: Decodable {
        let data: Trade
    }
}
