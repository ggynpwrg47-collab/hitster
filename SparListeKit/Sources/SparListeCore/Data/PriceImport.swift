import Foundation

/// Inhalt einer Importdatei. Format siehe README („Datenimport“).
public struct PriceImportPayload: Codable, Hashable, Sendable {
    public var brands: [Brand]
    public var products: [Product]
    public var prices: [PriceEntry]

    public init(brands: [Brand] = [], products: [Product] = [], prices: [PriceEntry] = []) {
        self.brands = brands
        self.products = products
        self.prices = prices
    }

    enum CodingKeys: String, CodingKey { case brands, products, prices }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        brands = try container.decodeIfPresent([Brand].self, forKey: .brands) ?? []
        products = try container.decodeIfPresent([Product].self, forKey: .products) ?? []
        prices = try container.decodeIfPresent([PriceEntry].self, forKey: .prices) ?? []
    }
}

public struct PriceImportSummary: Hashable, Sendable {
    public var added = 0
    public var updated = 0
}

public enum PriceImportError: Error, LocalizedError, Equatable {
    case invalidFormat(String)
    case unknownProduct(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidFormat(detail): return "Die Datei hat kein gültiges Importformat: \(detail)"
        case let .unknownProduct(id): return "Preis verweist auf unbekanntes Produkt „\(id)“."
        }
    }
}

/// Liest JSON-Importdateien und prüft Referenzen gegen den vorhandenen Katalog.
public struct JSONPriceImporter: Sendable {
    public init() {}

    public func decode(_ data: Data, existingCatalog: Catalog) throws -> PriceImportPayload {
        let payload: PriceImportPayload
        do {
            payload = try JSONCoding.decoder.decode(PriceImportPayload.self, from: data)
        } catch {
            throw PriceImportError.invalidFormat(String(describing: error))
        }
        let knownProductIDs = Set(existingCatalog.products.map(\.id) + payload.products.map(\.id))
        if let unknown = payload.prices.first(where: { !knownProductIDs.contains($0.productID) }) {
            throw PriceImportError.unknownProduct(unknown.productID)
        }
        // Importierte Preise werden als solche gekennzeichnet, sofern nicht explizit geschätzt.
        var normalized = payload
        normalized.prices = payload.prices.map { entry in
            var copy = entry
            if copy.source == .sampleData { copy.source = .imported }
            return copy
        }
        return normalized
    }
}
