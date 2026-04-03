import Foundation
import Combine

public enum WebSocketConnectionState: Sendable, Equatable {
    case connecting
    case connected
    case disconnected
    case error(message: String)
}

public struct WebSocketPriceTick: Sendable, Hashable, Identifiable {
    public let symbol: String
    public let price: String
    public let priceChangePercent: String?
    public let priceChange: String?
    public let quoteVolume: String?
    public let eventTime: Date?

    public var id: String { "\(symbol)-\(eventTime?.timeIntervalSince1970 ?? 0)-\(price)" }

    public init(symbol: String, price: String, priceChangePercent: String? = nil, priceChange: String? = nil, quoteVolume: String? = nil, eventTime: Date? = nil) {
        self.symbol = symbol
        self.price = price
        self.priceChangePercent = priceChangePercent
        self.priceChange = priceChange
        self.quoteVolume = quoteVolume
        self.eventTime = eventTime
    }
}

public protocol WebSocketClienting: Sendable {
    func connect() async
    func disconnect() async
    func subscribe(symbols: [String]) async

    var statePublisher: AnyPublisher<WebSocketConnectionState, Never> { get }
    var pricePublisher: AnyPublisher<WebSocketPriceTick, Never> { get }
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

    // MARK: - Public Publishers

    public var statePublisher: AnyPublisher<WebSocketConnectionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    public var pricePublisher: AnyPublisher<WebSocketPriceTick, Never> {
        priceSubject.eraseToAnyPublisher()
    }

    // MARK: - Private

    private let endpointURL: URL?
    private let session: URLSession
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    private let stateSubject = CurrentValueSubject<WebSocketConnectionState, Never>(.disconnected)
    private let priceSubject = PassthroughSubject<WebSocketPriceTick, Never>()

    private var task: URLSessionWebSocketTask?
    private var receiveLoopTask: Task<Void, Never>?
    private var pingLoopTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var connectingTask: Task<Void, Never>?

    private var state: WebSocketConnectionState {
        get { stateSubject.value }
        set { stateSubject.send(newValue) }
    }

    private var requestedDisconnect = false
    private var subscriptionSet = Set<String>() // normalized symbols (lowercased)
    private var subscribeId: Int = 1
    private var reconnectAttempt: Int = 0

    public static let shared = WebSocketClient()
    
    public init(
        endpointURL: URL? = URL(string: "wss://stream.binance.com:9443/ws"),
        session: URLSession = .shared
    ) {
        self.endpointURL = endpointURL
        self.session = session
    }

    deinit {
        receiveLoopTask?.cancel()
        pingLoopTask?.cancel()
        reconnectTask?.cancel()
        connectingTask?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - API

    public func connect() async {
        requestedDisconnect = false

        guard endpointURL != nil else {
            await transitionToErrorAndMaybeReconnect(message: Error.invalidEndpoint.localizedDescription)
            return
        }

        if case .connected = state { return }
        
        // If already connecting, wait for that task to finish
        if let currentTask = connectingTask {
            await currentTask.value
            return
        }

        connectingTask = Task {
            reconnectTask?.cancel()
            receiveLoopTask?.cancel()
            pingLoopTask?.cancel()

            state = .connecting

            let ws = session.webSocketTask(with: endpointURL!)
            task = ws
            ws.resume()
            
            // Wait briefly for the connection handshake to stabilize
            try? await Task.sleep(nanoseconds: 500_000_000)

            state = .connected
            reconnectAttempt = 0

            receiveLoopTask = Task { await self.receiveLoop() }
            pingLoopTask = Task { await self.pingLoop() }

            // Re-subscribe after reconnect / connect.
            if !subscriptionSet.isEmpty {
                await sendSubscribe(symbols: Array(subscriptionSet))
            }
            
            connectingTask = nil
        }
        
        await connectingTask?.value
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
        // Ticker stream example (@ticker):
        // {
        //   "e": "24hrTicker",
        //   "E": 123456789,
        //   "s": "BNBBTC",
        //   "p": "0.0015",
        //   "P": "250.00", // 24h price change percent
        //   "c": "0.0025", // Last price
        //   ...
        // }
        if let ticker = try? jsonDecoder.decode(BinanceTickerEvent.self, from: data) {
            let eventTime = ticker.eventTimeMs.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
            priceSubject.send(.init(
                symbol: ticker.symbol.lowercased(),
                price: ticker.lastPrice,
                priceChangePercent: ticker.priceChangePercent,
                priceChange: ticker.priceChange,
                quoteVolume: ticker.quoteVolume,
                eventTime: eventTime
            ))
            return
        }
    }

    private func sendSubscribe(symbols: [String]) async {
        guard let task, ifCaseConnected(state) else { return }

        let params = symbols
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .map { "\($0)@ticker" }

        guard !params.isEmpty else { return }

        let payload = BinanceSubscribeRequest(method: "SUBSCRIBE", params: params, id: nextSubscribeId())

        guard let data = try? jsonEncoder.encode(payload),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        
        // Use a small retry loop for the initial "Socket is not connected" race condition (POSIX 57)
        var lastError: Swift.Error?
        for attempt in 1...3 {
            do {
                if Task.isCancelled { return }
                try await task.send(.string(jsonString))
                return // Success!
            } catch {
                lastError = error
                let nsError = error as NSError
                if nsError.domain == NSPOSIXErrorDomain && nsError.code == 57 {
                    // Socket not quite ready, wait and try again
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 300_000_000)
                } else {
                    break // Fatal error
                }
            }
        }
        
        if let lastError {
            await transitionToErrorAndMaybeReconnect(message: "Subscribe failed: \(lastError.localizedDescription)")
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

private struct BinanceTickerEvent: Decodable, Sendable {
    let eventType: String?
    let eventTimeMs: Int64?
    let symbol: String
    let priceChangePercent: String
    let lastPrice: String
    let priceChange: String
    let quoteVolume: String

    enum CodingKeys: String, CodingKey {
        case eventType = "e"
        case eventTimeMs = "E"
        case symbol = "s"
        case priceChangePercent = "P"
        case lastPrice = "c"
        case priceChange = "p"
        case quoteVolume = "q"
    }
}
