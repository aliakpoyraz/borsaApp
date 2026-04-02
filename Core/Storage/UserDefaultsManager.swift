/**
 * VERİ ENTEGRASYONU - PORTFÖY YÖNETİMİ (COMPLETED)
 * Bu manager, kullanıcının satın aldığı Kripto ve BIST varlıklarını 
 * cihaz hafızasında (UserDefaults) kalıcı olarak saklar.
 * UI tarafındaki 'Ekle/Sil/Listele' işlemleri bu altyapı üzerinden yürütülür.
 */



import Foundation

public final class UserDefaultsManager: @unchecked Sendable {
    public static let shared = UserDefaultsManager()

    public enum StorageKey: String, Sendable {
        /// Keep in sync with `PortfolioService.assetsKey` to share the same persisted state.
        case portfolioAssetsV1 = "portfolio.assets.v1"
    }

    public enum Error: Swift.Error, LocalizedError, Sendable, Equatable {
        case invalidSymbol
        case encodeFailed
        case decodeFailed
        case assetNotFound

        public var errorDescription: String? {
            switch self {
            case .invalidSymbol:
                return "Symbol is invalid."
            case .encodeFailed:
                return "Failed to encode data for storage."
            case .decodeFailed:
                return "Failed to decode stored data."
            case .assetNotFound:
                return "Asset not found."
            }
        }
    }

    // MARK: - Dependencies

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "UserDefaultsManager.queue", qos: .userInitiated)

    // MARK: - Init

    /// Prefer `shared` for app usage. This initializer exists mainly for testing.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - Portfolio Assets API

    /// Returns all stored portfolio assets. If nothing is stored, returns an empty array.
    public func fetchPortfolioAssets() throws -> [PortfolioAsset] {
        try queue.sync {
            try loadAssets()
        }
    }

    /// Inserts or replaces a single asset based on `PortfolioAsset.id`.
    public func savePortfolioAsset(_ asset: PortfolioAsset) throws {
        try queue.sync {
            let validated = try validate(asset)
            var assets = try loadAssets()

            if let idx = assets.firstIndex(where: { $0.id == validated.id }) {
                assets[idx] = validated
            } else {
                assets.append(validated)
            }

            assets.sort { ($0.kind.rawValue, $0.symbol) < ($1.kind.rawValue, $1.symbol) }
            try storeAssets(assets)
        }
    }

    /// Replaces all assets with the provided list (deduplicated by `id`).
    public func savePortfolioAssets(_ assets: [PortfolioAsset]) throws {
        try queue.sync {
            var uniqueById: [String: PortfolioAsset] = [:]
            uniqueById.reserveCapacity(assets.count)

            for asset in assets {
                let validated = try validate(asset)
                uniqueById[validated.id] = validated
            }

            var merged = Array(uniqueById.values)
            merged.sort { ($0.kind.rawValue, $0.symbol) < ($1.kind.rawValue, $1.symbol) }
            try storeAssets(merged)
        }
    }

    /// Deletes an asset by `kind` + `symbol`. Throws if the asset does not exist.
    public func deletePortfolioAsset(kind: PortfolioAssetKind, symbol: String) throws {
        let normalizedSymbol = normalize(symbol)
        guard !normalizedSymbol.isEmpty else { throw Error.invalidSymbol }

        try queue.sync {
            var assets = try loadAssets()
            let id = "\(kind.rawValue):\(normalizedSymbol)"
            guard let idx = assets.firstIndex(where: { $0.id == id }) else { throw Error.assetNotFound }
            assets.remove(at: idx)
            try storeAssets(assets)
        }
    }

    /// Deletes an asset by `PortfolioAsset.id`. Throws if the asset does not exist.
    public func deletePortfolioAsset(id: String) throws {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Error.assetNotFound }

        try queue.sync {
            var assets = try loadAssets()
            guard let idx = assets.firstIndex(where: { $0.id == trimmed }) else { throw Error.assetNotFound }
            assets.remove(at: idx)
            try storeAssets(assets)
        }
    }

    /// Clears all stored assets.
    public func deleteAllPortfolioAssets() {
        queue.sync {
            defaults.removeObject(forKey: StorageKey.portfolioAssetsV1.rawValue)
        }
    }

    // MARK: - Internals

    private func validate(_ asset: PortfolioAsset) throws -> PortfolioAsset {
        let symbol = normalize(asset.symbol)
        guard !symbol.isEmpty else { throw Error.invalidSymbol }

        // Ensure symbol normalization is consistent with the model's `id` logic.
        if asset.symbol == symbol {
            return asset
        }

        return PortfolioAsset(
            kind: asset.kind,
            symbol: symbol,
            quantity: asset.quantity,
            averageBuyPrice: asset.averageBuyPrice,
            lastKnownPrice: asset.lastKnownPrice,
            lastUpdatedAt: asset.lastUpdatedAt
        )
    }

    private func loadAssets() throws -> [PortfolioAsset] {
        guard let data = defaults.data(forKey: StorageKey.portfolioAssetsV1.rawValue) else { return [] }
        do {
            return try decoder.decode([PortfolioAsset].self, from: data)
        } catch {
            throw Error.decodeFailed
        }
    }

    private func storeAssets(_ assets: [PortfolioAsset]) throws {
        do {
            let data = try encoder.encode(assets)
            defaults.set(data, forKey: StorageKey.portfolioAssetsV1.rawValue)
        } catch {
            throw Error.encodeFailed
        }
    }

    private func normalize(_ symbol: String) -> String {
        symbol
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }
}

