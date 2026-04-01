import Foundation

public enum WebSocketConnectionState: Sendable, Equatable {
    case connecting
    case connected
    case disconnected
    case error(message: String)
}

public struct WebSocketPriceTick: Sendable, Hashable, Identifiable {
    public let symbol: String
    public let price: String
    public let eventTime: Date?

    public var id: String { "\(symbol)-\(eventTime?.timeIntervalSince1970 ?? 0)-\(price)" }

    public init(symbol: String, price: String, eventTime: Date?) {
        self.symbol = symbol
        self.price = price
        self.eventTime = eventTime
    }
}

public protocol WebSocketClienting: Sendable {
    func connect() async
    func disconnect() async
    func subscribe(symbols: [String]) async

    var stateStream: AsyncStream<WebSocketConnectionState> { get }
    var priceStream: AsyncStream<WebSocketPriceTick> { get }
}

/// Binance WebSocket client for live prices.
/// Endpoint: wss://stream.binance.com:9443/ws
@MainActor
public final class WebSocketClient: WebSocketClienting, @unchecked Sendable {
    public enum Error: Swift.Error, LocalizedError, Sendable {
        case invalidEndpoint
        case messageEncodingFailed
        case messageDecodingFailed

        public var errorDescription: String? {
            switch self {
            case .invalidEndpoint:
                return "Binance websocket endpoint URL could not be constructed."
            case .messageEncodingFailed:
                return "Websocket message could not be encoded."
            case .messageDecodingFailed:
                return "Websocket message could not be decoded."
            }
        }
    }

    // MARK: - Public Streams

    public let stateStream: AsyncStream<WebSocketConnectionState>
    public let priceStream: AsyncStream<WebSocketPriceTick>

    // MARK: - Private

    private let endpointURL: URL?
    private let session: URLSession
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    private var stateContinuation: AsyncStream<WebSocketConnectionState>.Continuation?
    private var priceContinuation: AsyncStream<WebSocketPriceTick>.Continuation?

    private var task: URLSessionWebSocketTask?
    private var receiveLoopTask: Task<Void, Never>?
    private var pingLoopTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    private var state: WebSocketConnectionState = .disconnected {
        didSet {
            stateContinuation?.yield(state)
        }
    }

    private var requestedDisconnect = false
    private var subscriptionSet = Set<String>() // normalized symbols (lowercased)
    private var subscribeId: Int = 1
    private var reconnectAttempt: Int = 0

    public init(
        endpointURL: URL? = URL(string: "wss://stream.binance.com:9443/ws"),
        session: URLSession = .shared
    ) {
        self.endpointURL = endpointURL
        self.session = session

        var stateCont: AsyncStream<WebSocketConnectionState>.Continuation?
        self.stateStream = AsyncStream<WebSocketConnectionState> { cont in
            stateCont = cont
        }
        self.stateContinuation = stateCont

        var priceCont: AsyncStream<WebSocketPriceTick>.Continuation?
        self.priceStream = AsyncStream<WebSocketPriceTick> { cont in
            priceCont = cont
        }
        self.priceContinuation = priceCont

        self.stateContinuation?.yield(.disconnected)
    }

    deinit {
        receiveLoopTask?.cancel()
        pingLoopTask?.cancel()
        reconnectTask?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        stateContinuation?.finish()
        priceContinuation?.finish()
    }

    // MARK: - API

    public func connect() async {
        requestedDisconnect = false

        guard endpointURL != nil else {
            await transitionToErrorAndMaybeReconnect(message: Error.invalidEndpoint.localizedDescription)
            return
        }

        if case .connected = state { return }
        if case .connecting = state { return }

        reconnectTask?.cancel()
        receiveLoopTask?.cancel()
        pingLoopTask?.cancel()

        state = .connecting

        let ws = session.webSocketTask(with: endpointURL!)
        task = ws
        ws.resume()

        state = .connected
        reconnectAttempt = 0

        receiveLoopTask = Task { await self.receiveLoop() }
        pingLoopTask = Task { await self.pingLoop() }

        // Re-subscribe after reconnect / connect.
        if !subscriptionSet.isEmpty {
            await sendSubscribe(symbols: Array(subscriptionSet))
        }
    }

    public func disconnect() async {
        requestedDisconnect = true
        reconnectTask?.cancel()

        receiveLoopTask?.cancel()
        receiveLoopTask = nil

        pingLoopTask?.cancel()
        pingLoopTask = nil

        if let task {
            task.cancel(with: .normalClosure, reason: nil)
        }
        task = nil

        state = .disconnected
    }

    /// Subscribes to symbols like "btcusdt", "ethusdt".
    /// Under the hood this subscribes to `<symbol>@trade` streams (live trade prices).
    public func subscribe(symbols: [String]) async {
        let normalized = symbols
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        for s in normalized { subscriptionSet.insert(s) }

        guard (ifCaseConnected(state)) else {
            // If not connected yet, we'll subscribe automatically when connected.
            if ifCaseDisconnected(state) || (ifCaseError(state)) { await connect() }
            return
        }

        await sendSubscribe(symbols: normalized)
    }

    // MARK: - Internals

    private func ifCaseError(_ state: WebSocketConnectionState) -> Bool {
        if case .error = state { return true }
        return false
    }

    private func ifCaseConnected(_ state: WebSocketConnectionState) -> Bool {
        if case .connected = state { return true }
        return false
    }

    private func ifCaseDisconnected(_ state: WebSocketConnectionState) -> Bool {
        if case .disconnected = state { return true }
        return false
    }

    private func transitionToDisconnectedAndMaybeReconnect() async {
        state = .disconnected
        guard !requestedDisconnect else { return }
        scheduleReconnect()
    }

    private func transitionToErrorAndMaybeReconnect(message: String) async {
        state = .error(message: message)
        guard !requestedDisconnect else { return }
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()

        reconnectTask = Task {
            guard !requestedDisconnect else { return }

            // Exponential backoff with cap: 1s, 2s, 4s, 8s, 16s, 30s...
            reconnectAttempt += 1
            let base: Double = 1
            let cap: Double = 30
            let delay = min(cap, base * pow(2, Double(max(0, reconnectAttempt - 1))))
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard !requestedDisconnect else { return }
            await connect()
        }
    }

    private func pingLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 15 * 1_000_000_000)
            if Task.isCancelled { return }

            guard let task, ifCaseConnected(state) else { continue }

            do {
                try await sendPing(task)
            } catch {
                await transitionToErrorAndMaybeReconnect(message: error.localizedDescription)
                return
            }
        }
    }

    private func sendPing(_ task: URLSessionWebSocketTask) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Swift.Error>) in
            task.sendPing { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            guard let task else {
                await transitionToDisconnectedAndMaybeReconnect()
                return
            }

            do {
                let msg = try await task.receive()
                if Task.isCancelled { return }

                switch msg {
                case .data(let data):
                    handleIncomingData(data)
                case .string(let text):
                    handleIncomingText(text)
                @unknown default:
                    break
                }
            } catch {
                await transitionToErrorAndMaybeReconnect(message: error.localizedDescription)
                return
            }
        }
    }

    private func handleIncomingText(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        handleIncomingData(data)
    }

    private func handleIncomingData(_ data: Data) {
        // Trade stream example:
        // {
        //   "e":"trade","E":171..., "s":"BTCUSDT",
        //   "p":"65000.12", ...
        // }
        // Note: Binance also sends subscription acks like {"result":null,"id":1}.
        if let trade = try? jsonDecoder.decode(BinanceTradeEvent.self, from: data) {
            let eventTime = trade.eventTimeMs.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
            priceContinuation?.yield(.init(symbol: trade.symbol.lowercased(), price: trade.price, eventTime: eventTime))
            return
        }
    }

    private func sendSubscribe(symbols: [String]) async {
        guard let task, ifCaseConnected(state) else { return }

        let params = symbols
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .map { "\($0)@trade" }

        guard !params.isEmpty else { return }

        let payload = BinanceSubscribeRequest(method: "SUBSCRIBE", params: params, id: nextSubscribeId())

        guard let data = try? jsonEncoder.encode(payload) else { return }
        do {
            try await task.send(.data(data))
        } catch {
            await transitionToErrorAndMaybeReconnect(message: error.localizedDescription)
        }
    }

    private func nextSubscribeId() -> Int {
        defer { subscribeId += 1 }
        return subscribeId
    }
}

// MARK: - Binance DTOs

private struct BinanceSubscribeRequest: Encodable, Sendable {
    let method: String
    let params: [String]
    let id: Int
}

private struct BinanceTradeEvent: Decodable, Sendable {
    let eventType: String?
    let eventTimeMs: Int64?
    let symbol: String
    let price: String

    enum CodingKeys: String, CodingKey {
        case eventType = "e"
        case eventTimeMs = "E"
        case symbol = "s"
        case price = "p"
    }
}
