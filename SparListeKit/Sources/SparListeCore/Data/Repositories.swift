import Foundation

// Abstrakte Schnittstellen der Datenschicht. View Models und Domänenlogik hängen nur
// von diesen Protokollen ab – nie von einer konkreten Datenquelle. Eine spätere
// Anbindung echter APIs oder Importe implementiert einfach eines dieser Protokolle.

/// Beschreibung einer Preisdatenquelle (für die Transparenzanzeige in der App).
public struct DataSourceDescriptor: Hashable, Sendable {
    public var name: String
    public var isLive: Bool
    public var limitations: String

    public init(name: String, isLive: Bool, limitations: String) {
        self.name = name
        self.isLive = isLive
        self.limitations = limitations
    }
}

/// Lesender Zugriff auf Preise und Angebote.
public protocol PriceDataSource: Sendable {
    var descriptor: DataSourceDescriptor { get }
    /// Alle bekannten Preiseinträge für die angegebenen Läden.
    func priceEntries(forStoreIDs storeIDs: Set<String>) async throws -> [PriceEntry]
}

/// Schreibender Zugriff auf lokal gepflegte Preise.
public protocol PriceRepository: PriceDataSource {
    func allPriceEntries() async throws -> [PriceEntry]
    func save(_ entry: PriceEntry) async throws
    func deletePriceEntry(id: String) async throws
}

public protocol ShoppingListRepository: Sendable {
    func allLists() async throws -> [ShoppingList]
    func list(id: UUID) async throws -> ShoppingList?
    func save(_ list: ShoppingList) async throws
    func deleteList(id: UUID) async throws
}

public protocol StoreRepository: Sendable {
    func allStores() async throws -> [Store]
    func save(_ store: Store) async throws
    func deleteStore(id: String) async throws
}

public protocol CatalogRepository: Sendable {
    func catalog() async throws -> Catalog
    func save(_ product: Product) async throws
    func save(_ brand: Brand) async throws
    func deleteProduct(id: String) async throws
}

public protocol SettingsRepository: Sendable {
    func settings() async throws -> OptimizationSettings
    func save(_ settings: OptimizationSettings) async throws
}

/// Kombiniert mehrere Preisquellen (z. B. lokale Daten + späterer API-Import).
public struct CompositePriceDataSource: PriceDataSource {
    public var sources: [any PriceDataSource]

    public init(sources: [any PriceDataSource]) {
        self.sources = sources
    }

    public var descriptor: DataSourceDescriptor {
        DataSourceDescriptor(
            name: sources.map(\.descriptor.name).joined(separator: " + "),
            isLive: sources.contains { $0.descriptor.isLive },
            limitations: sources.map(\.descriptor.limitations).joined(separator: " ")
        )
    }

    public func priceEntries(forStoreIDs storeIDs: Set<String>) async throws -> [PriceEntry] {
        var result: [PriceEntry] = []
        for source in sources {
            result += try await source.priceEntries(forStoreIDs: storeIDs)
        }
        return result
    }
}
