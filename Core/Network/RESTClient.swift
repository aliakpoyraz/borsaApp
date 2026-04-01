import Foundation

public final class RESTClient: @unchecked Sendable {
    public struct Configuration: Sendable {
        public var timeout: TimeInterval
        public var defaultHeaders: [String: String]
        public var allowsCellularAccess: Bool
        public var cache: CacheConfiguration
        public var jsonDecoder: JSONDecoder
        public var jsonEncoder: JSONEncoder

        public init(
            timeout: TimeInterval = 30,
            defaultHeaders: [String: String] = [
                "Accept": "application/json",
                "Content-Type": "application/json; charset=utf-8"
            ],
            allowsCellularAccess: Bool = true,
            cache: CacheConfiguration = .init(),
            jsonDecoder: JSONDecoder = JSONDecoder(),
            jsonEncoder: JSONEncoder = JSONEncoder()
        ) {
            self.timeout = timeout
            self.defaultHeaders = defaultHeaders
            self.allowsCellularAccess = allowsCellularAccess
            self.cache = cache
            self.jsonDecoder = jsonDecoder
            self.jsonEncoder = jsonEncoder
        }
    }

    public struct CacheConfiguration: Sendable {
        public var countLimit: Int
        public var totalCostLimitBytes: Int
        public var defaultTTL: TimeInterval?

        public init(countLimit: Int = 200, totalCostLimitBytes: Int = 50 * 1024 * 1024, defaultTTL: TimeInterval? = nil) {
            self.countLimit = countLimit
            self.totalCostLimitBytes = totalCostLimitBytes
            self.defaultTTL = defaultTTL
        }
    }

    public enum HTTPMethod: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
        case head = "HEAD"
        case options = "OPTIONS"
    }

    public enum Body: Sendable {
        case data(Data, contentType: String?)
        case jsonEncodable(any Encodable)

        fileprivate func encoded(using encoder: JSONEncoder) throws -> (data: Data, contentType: String?) {
            switch self {
            case let .data(data, contentType):
                return (data, contentType)
            case let .jsonEncodable(value):
                let data = try AnyEncodable(value).encode(using: encoder)
                return (data, "application/json; charset=utf-8")
            }
        }
    }

    public struct Request: Sendable {
        public var url: URL
        public var method: HTTPMethod
        public var headers: [String: String]
        public var queryItems: [URLQueryItem]
        public var body: Body?
        public var cachePolicy: CachePolicy

        public init(
            url: URL,
            method: HTTPMethod = .get,
            headers: [String: String] = [:],
            queryItems: [URLQueryItem] = [],
            body: Body? = nil,
            cachePolicy: CachePolicy = .useCacheIfAvailable
        ) {
            self.url = url
            self.method = method
            self.headers = headers
            self.queryItems = queryItems
            self.body = body
            self.cachePolicy = cachePolicy
        }
    }

    public enum CachePolicy: Sendable {
        case ignoreCache
        case useCacheIfAvailable
        case useCache(maxAge: TimeInterval)
        case refreshIgnoringCache
    }

    public enum Error: Swift.Error, LocalizedError, Sendable {
        case invalidURL
        case transport(URLError)
        case nonHTTPResponse
        case httpStatus(code: Int, data: Data)
        case decoding(Swift.Error)

        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL."
            case .transport(let e): return e.localizedDescription
            case .nonHTTPResponse: return "Non-HTTP response."
            case .httpStatus(let code, _): return "HTTP error status: \(code)."
            case .decoding(let e): return "Decoding failed: \(e.localizedDescription)"
            }
        }
    }

    private final class CacheEntry: NSObject {
        let data: Data
        let storedAt: Date
        let ttl: TimeInterval?

        init(data: Data, storedAt: Date, ttl: TimeInterval?) {
            self.data = data
            self.storedAt = storedAt
            self.ttl = ttl
        }

        func isValid(at date: Date) -> Bool {
            guard let ttl else { return true }
            return date.timeIntervalSince(storedAt) <= ttl
        }
    }

    private let session: URLSession
    private let config: Configuration
    private let cache = NSCache<NSString, CacheEntry>()
    private let now: @Sendable () -> Date

    public init(
        configuration: Configuration = .init(),
        session: URLSession = .shared,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.config = configuration
        self.session = session
        self.now = now

        cache.countLimit = configuration.cache.countLimit
        cache.totalCostLimit = configuration.cache.totalCostLimitBytes
    }

    public func send(_ request: Request) async throws -> Data {
        let built = try buildURLRequest(from: request)
        let key = cacheKey(for: request, builtURL: built.url, builtBody: built.httpBody)

        switch request.cachePolicy {
        case .ignoreCache, .refreshIgnoringCache:
            break
        case .useCacheIfAvailable:
            if let cached = cachedData(forKey: key, maxAge: config.cache.defaultTTL) { return cached }
        case .useCache(let maxAge):
            if let cached = cachedData(forKey: key, maxAge: maxAge) { return cached }
        }

        do {
            let (data, response) = try await session.data(for: built)
            guard let http = response as? HTTPURLResponse else { throw Error.nonHTTPResponse }

            guard (200...299).contains(http.statusCode) else {
                throw Error.httpStatus(code: http.statusCode, data: data)
            }

            let ttl = ttlToStore(from: request.cachePolicy)
            if ttl != nil || request.cachePolicy == .useCacheIfAvailable {
                storeCache(data: data, forKey: key, ttl: ttl ?? config.cache.defaultTTL)
            }

            return data
        } catch let e as URLError {
            throw Error.transport(e)
        }
    }

    public func send<T: Decodable>(_ request: Request, decodeTo type: T.Type = T.self) async throws -> T {
        let data = try await send(request)
        do {
            return try config.jsonDecoder.decode(T.self, from: data)
        } catch {
            throw Error.decoding(error)
        }
    }

    public func invalidateCache() {
        cache.removeAllObjects()
    }

    public func invalidateCache(for request: Request) {
        let key = cacheKey(for: request, builtURL: buildURL(for: request), builtBody: nil)
        cache.removeObject(forKey: key as NSString)
    }

    private func buildURL(for request: Request) -> URL? {
        var comps = URLComponents(url: request.url, resolvingAgainstBaseURL: false)
        let existing = comps?.queryItems ?? []
        comps?.queryItems = (existing + request.queryItems).isEmpty ? nil : (existing + request.queryItems)
        return comps?.url
    }

    private func buildURLRequest(from request: Request) throws -> URLRequest {
        guard let finalURL = buildURL(for: request) else { throw Error.invalidURL }

        var req = URLRequest(url: finalURL, timeoutInterval: config.timeout)
        req.httpMethod = request.method.rawValue
        req.allowsCellularAccess = config.allowsCellularAccess

        var headers = config.defaultHeaders
        headers.merge(request.headers, uniquingKeysWith: { _, new in new })

        if let body = request.body {
            let encoded = try body.encoded(using: config.jsonEncoder)
            req.httpBody = encoded.data
            if let contentType = encoded.contentType, headers["Content-Type"] == nil {
                headers["Content-Type"] = contentType
            }
        }

        for (k, v) in headers {
            req.setValue(v, forHTTPHeaderField: k)
        }

        return req
    }

    private func cachedData(forKey key: NSString, maxAge: TimeInterval?) -> Data? {
        guard let entry = cache.object(forKey: key) else { return nil }
        let effectiveTTL = entry.ttl ?? maxAge
        if let effectiveTTL {
            return now().timeIntervalSince(entry.storedAt) <= effectiveTTL ? entry.data : nil
        }
        return entry.data
    }

    private func storeCache(data: Data, forKey key: NSString, ttl: TimeInterval?) {
        let entry = CacheEntry(data: data, storedAt: now(), ttl: ttl)
        cache.setObject(entry, forKey: key, cost: data.count)
    }

    private func ttlToStore(from policy: CachePolicy) -> TimeInterval? {
        switch policy {
        case .useCache(let maxAge): return maxAge
        case .useCacheIfAvailable: return nil
        case .ignoreCache, .refreshIgnoringCache: return nil
        }
    }

    private func cacheKey(for request: Request, builtURL: URL?, builtBody: Data?) -> NSString {
        let urlString = (builtURL ?? request.url).absoluteString
        let method = request.method.rawValue
        let bodyKey = builtBody.map { "b:\(fnv1a64Hex($0))" } ?? "-"

        return "\(method) \(urlString) \(bodyKey)" as NSString
    }

    private func fnv1a64Hex(_ data: Data) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        for b in data {
            hash ^= UInt64(b)
            hash &*= prime
        }
        return String(hash, radix: 16, uppercase: false)
    }
}

private struct AnyEncodable: Encodable, Sendable {
    private let _encode: @Sendable (Encoder) throws -> Void

    init(_ encodable: any Encodable) {
        self._encode = { encoder in
            try encodable.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }

    func encode(using encoder: JSONEncoder) throws -> Data {
        try encoder.encode(self)
    }
}
