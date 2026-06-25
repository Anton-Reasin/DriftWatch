import Foundation

import SharedKit

public actor PriceSourceBinance: PriceSource {
    private let symbols: [Symbol]
    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private let backoff = Backoff()
    private let clock: any Clock<Duration>
    private var attempt = 0

    private nonisolated let stream: AsyncStream<TransportEvent>
    private nonisolated let continuation: AsyncStream<TransportEvent>.Continuation

    public init(
        symbols: [Symbol],
        session: URLSession = .shared,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.symbols = symbols
        self.session = session
        self.clock = clock
        (stream, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(256))
    }

    public nonisolated func events() -> AsyncStream<TransportEvent> {
        stream
    }

    private var stopped = false

    /// Closes the socket and stops the reconnect loop when the stream's only
    /// consumer goes away. Without this the WebSocket and backoff loop outlive
    /// the screen (concurrency rule: AsyncStream wrappers clean up on terminate).
    private func shutdown() {
        stopped = true
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    public func connect() async {
        continuation.onTermination = { [weak self] _ in
            Task { await self?.shutdown() }
        }
        while !stopped, !Task.isCancelled {
            let streamPath = symbols.map(\.streamName).joined(separator: "/")
            var components = URLComponents(string: "wss://data-stream.binance.vision/stream")!
            components.queryItems = [URLQueryItem(name: "streams", value: streamPath)]
            guard let url = components.url else { return }

            let task = session.webSocketTask(with: url)
            self.task = task
            continuation.yield(.status(attempt == 0 ? .connecting : .reconnecting))
            task.resume()
            await receiveLoop(on: task)
            let wait = backoff.delay(for: attempt)
            attempt += 1
            try? await clock.sleep(for: wait)
        }
    }

    private func receiveLoop(on task: URLSessionWebSocketTask) async {
        var announcedLive = false
        while true {
            guard let message = try? await task.receive() else {
                return
            }
            if case .string(let text) = message, let tick = Self.makeTick(from: text) {
                if !announcedLive {
                    announcedLive = true
                    attempt = 0
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
