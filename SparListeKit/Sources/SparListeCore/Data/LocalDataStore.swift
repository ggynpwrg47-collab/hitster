import Foundation

/// Lokale Datenquelle: hält den Datenbestand im Speicher und schreibt jede Änderung
/// über `DataPersistence` zurück. Implementiert alle Repository-Protokolle.
public actor LocalDataStore: ShoppingListRepository, StoreRepository, CatalogRepository, PriceRepository, SettingsRepository {
    private let persistence: any DataPersistence
    private var data: AppData

    public nonisolated let descriptor = DataSourceDescriptor(
        name: "Lokale Daten",
        isLive: false,
        limitations: "Preise und Angebote werden lokal gepflegt (Beispieldaten, manuelle Eingaben oder JSON-Import). Es findet kein automatischer Abgleich mit den Supermärkten statt."
    )

    /// Lädt den Bestand. Ist noch nichts gespeichert, wird `seed()` verwendet und gespeichert.
    public init(persistence: any DataPersistence, seed: @Sendable () -> AppData = { SampleData.make() }) throws {
        self.persistence = persistence
        if let loaded = try persistence.load() {
            self.data = loaded
        } else {
            let initial = seed()
            try persistence.save(initial)
            self.data = initial
        }
    }

    public func snapshot() -> AppData { data }

    /// Ersetzt den kompletten Bestand (z. B. „Beispieldaten zurücksetzen“).
    public func replaceAll(with newData: AppData) throws {
        data = newData
        try persist()
    }

    private func persist() throws {
        try persistence.save(data)
    }

    // MARK: ShoppingListRepository

    public func allLists() -> [ShoppingList] {
        data.lists.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func list(id: UUID) -> ShoppingList? {
        data.lists.first { $0.id == id }
    }

    public func save(_ list: ShoppingList) throws {
        upsert(list, into: &data.lists)
        try persist()
    }

    public func deleteList(id: UUID) throws {
        data.lists.removeAll { $0.id == id }
        try persist()
    }

    // MARK: StoreRepository

    public func allStores() -> [Store] {
        data.stores.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    public func save(_ store: Store) throws {
        upsert(store, into: &data.stores)
        try persist()
    }

    public func deleteStore(id: String) throws {
        data.stores.removeAll { $0.id == id }
        data.prices.removeAll { $0.storeID == id }
        try persist()
    }

    // MARK: CatalogRepository

    public func catalog() -> Catalog { data.catalog }

    public func save(_ product: Product) throws {
        upsert(product, into: &data.products)
        try persist()
    }

    public func save(_ brand: Brand) throws {
        upsert(brand, into: &data.brands)
        try persist()
    }

    public func deleteProduct(id: String) throws {
        data.products.removeAll { $0.id == id }
        data.prices.removeAll { $0.productID == id }
        try persist()
    }

    // MARK: PriceRepository

    public func priceEntries(forStoreIDs storeIDs: Set<String>) -> [PriceEntry] {
        data.prices.filter { storeIDs.contains($0.storeID) }
    }

    public func allPriceEntries() -> [PriceEntry] { data.prices }

    public func save(_ entry: PriceEntry) throws {
        upsert(entry, into: &data.prices)
        try persist()
    }

    public func deletePriceEntry(id: String) throws {
        data.prices.removeAll { $0.id == id }
        try persist()
    }

    /// Übernimmt einen Import: Einträge mit gleicher ID werden ersetzt, neue ergänzt.
    @discardableResult
    public func apply(_ payload: PriceImportPayload) throws -> PriceImportSummary {
        var summary = PriceImportSummary()
        for brand in payload.brands {
            if data.brands.contains(where: { $0.id == brand.id }) { summary.updated += 1 } else { summary.added += 1 }
            upsert(brand, into: &data.brands)
        }
        for product in payload.products {
            if data.products.contains(where: { $0.id == product.id }) { summary.updated += 1 } else { summary.added += 1 }
            upsert(product, into: &data.products)
        }
        for price in payload.prices {
            if data.prices.contains(where: { $0.id == price.id }) { summary.updated += 1 } else { summary.added += 1 }
            upsert(price, into: &data.prices)
        }
        try persist()
        return summary
    }

    // MARK: SettingsRepository

    public func settings() -> OptimizationSettings { data.settings }

    public func save(_ settings: OptimizationSettings) throws {
        data.settings = settings
        try persist()
    }

    // MARK: Helpers

    private func upsert<T: Identifiable>(_ element: T, into array: inout [T]) {
        if let index = array.firstIndex(where: { $0.id == element.id }) {
            array[index] = element
        } else {
            array.append(element)
        }
    }
}
