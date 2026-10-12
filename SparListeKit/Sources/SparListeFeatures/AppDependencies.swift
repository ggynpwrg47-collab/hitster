import Foundation
import SparListeCore

/// Abhängigkeiten der View Models. Alle Datenzugriffe laufen über Protokolle,
/// sodass Datenquellen (lokal, Import, spätere APIs) austauschbar sind.
public struct AppDependencies: Sendable {
    public var lists: any ShoppingListRepository
    public var stores: any StoreRepository
    public var catalog: any CatalogRepository
    public var prices: any PriceRepository
    public var settings: any SettingsRepository
    public var optimizer: ShoppingOptimizer
    public var now: @Sendable () -> Date
    /// Setzt den Datenbestand auf die Beispieldaten zurück (optional).
    public var resetToSampleData: (@Sendable () async throws -> Void)?
    /// Importiert eine JSON-Datei mit Marken, Produkten und Preisen (optional).
    public var importPriceFile: (@Sendable (Data) async throws -> PriceImportSummary)?

    public init(
        lists: any ShoppingListRepository,
        stores: any StoreRepository,
        catalog: any CatalogRepository,
        prices: any PriceRepository,
        settings: any SettingsRepository,
        optimizer: ShoppingOptimizer = ShoppingOptimizer(),
        now: @escaping @Sendable () -> Date = { Date() },
        resetToSampleData: (@Sendable () async throws -> Void)? = nil,
        importPriceFile: (@Sendable (Data) async throws -> PriceImportSummary)? = nil
    ) {
        self.lists = lists
        self.stores = stores
        self.catalog = catalog
        self.prices = prices
        self.settings = settings
        self.optimizer = optimizer
        self.now = now
        self.resetToSampleData = resetToSampleData
        self.importPriceFile = importPriceFile
    }

    /// Verdrahtet alle Repositories mit einem `LocalDataStore`.
    public static func local(_ store: LocalDataStore, now: @escaping @Sendable () -> Date = { Date() }) -> AppDependencies {
        AppDependencies(
            lists: store,
            stores: store,
            catalog: store,
            prices: store,
            settings: store,
            now: now,
            resetToSampleData: {
                try await store.replaceAll(with: SampleData.make(now: now()))
            },
            importPriceFile: { data in
                let catalog = await store.catalog()
                let payload = try JSONPriceImporter().decode(data, existingCatalog: catalog)
                return try await store.apply(payload)
            }
        )
    }

    /// In-Memory-Variante mit Beispieldaten (Vorschauen, Tests).
    public static func preview(now: Date = Date()) -> AppDependencies {
        let store = try! LocalDataStore(persistence: InMemoryPersistence(), seed: { SampleData.make(now: now) })
        return local(store, now: { now })
    }
}

/// Lade-/Fehlerzustand eines Bildschirms.
public enum LoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)

    public var errorMessage: String? {
        if case let .failed(message) = self { return message }
        return nil
    }
}

extension Error {
    var userMessage: String {
        (self as? LocalizedError)?.errorDescription ?? String(describing: self)
    }
}
