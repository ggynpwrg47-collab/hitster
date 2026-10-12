import Foundation

/// Gesamter lokal gespeicherter Datenbestand.
public struct AppData: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var lists: [ShoppingList]
    public var stores: [Store]
    public var products: [Product]
    public var brands: [Brand]
    public var prices: [PriceEntry]
    public var settings: OptimizationSettings

    public init(
        lists: [ShoppingList] = [],
        stores: [Store] = [],
        products: [Product] = [],
        brands: [Brand] = [],
        prices: [PriceEntry] = [],
        settings: OptimizationSettings = .default
    ) {
        self.schemaVersion = AppData.currentSchemaVersion
        self.lists = lists
        self.stores = stores
        self.products = products
        self.brands = brands
        self.prices = prices
        self.settings = settings
    }

    public var catalog: Catalog { Catalog(products: products, brands: brands) }
}

/// Speichert und lädt den Datenbestand.
public protocol DataPersistence: Sendable {
    func load() throws -> AppData?
    func save(_ data: AppData) throws
}

/// Persistenz als JSON-Datei (Standard in der App: Application Support).
public struct JSONFilePersistence: DataPersistence {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Standardort im Application-Support-Verzeichnis der App.
    public static func defaultLocation(fileName: String = "sparliste.json") throws -> JSONFilePersistence {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return JSONFilePersistence(fileURL: directory.appendingPathComponent(fileName))
    }

    public func load() throws -> AppData? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONCoding.decoder.decode(AppData.self, from: data)
    }

    public func save(_ data: AppData) throws {
        let encoded = try JSONCoding.encoder.encode(data)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoded.write(to: fileURL, options: [.atomic])
    }
}

/// Persistenz im Speicher (Tests, Vorschauen).
public final class InMemoryPersistence: DataPersistence, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: AppData?
    public private(set) var saveCount = 0

    public init(initial: AppData? = nil) {
        self.stored = initial
    }

    public func load() throws -> AppData? {
        lock.lock(); defer { lock.unlock() }
        return stored
    }

    public func save(_ data: AppData) throws {
        lock.lock(); defer { lock.unlock() }
        stored = data
        saveCount += 1
    }
}

public enum JSONCoding {
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
