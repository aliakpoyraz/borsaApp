import Foundation

public protocol CryptoServicing: Sendable {
    func fetchAll24hTickers(cachePolicy: RESTClient.CachePolicy) async throws -> [Crypto]
}

public final class CryptoService: CryptoServicing, @unchecked Sendable {
    public enum Error: Swift.Error, LocalizedError, Sendable {
        case invalidEndpoint
        case requestFailed(RESTClient.Error)

        public var errorDescription: String? {
            switch self {
            case .invalidEndpoint:
                return "Binance endpoint URL could not be constructed."
            case .requestFailed(let error):
                return error.localizedDescription
            }
        }
    }

    private let client: RESTClient
    private let endpointURL: URL?

    public init(
        client: RESTClient = RESTClient(),
        endpointURL: URL? = URL(string: "https://api.binance.com/api/v3/ticker/24hr")
    ) {
        self.client = client
        self.endpointURL = endpointURL
    }

    public func fetchAll24hTickers(cachePolicy: RESTClient.CachePolicy = .refreshIgnoringCache) async throws -> [Crypto] {
        guard let endpointURL else { throw Error.invalidEndpoint }

        let request = RESTClient.Request(
            url: endpointURL,
            method: .get,
            cachePolicy: cachePolicy
        )

        do {
            // Binance returns an array of tickers. Our `Crypto` model matches key names directly.
            return try await client.send(request, decodeTo: [Crypto].self)
        } catch let e as RESTClient.Error {
            throw Error.requestFailed(e)
        }
    }
}
