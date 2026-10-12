import Foundation
import Observation
import SparListeCore

/// Läden verwalten und Berechnungseinstellungen (max. Ladenanzahl, Modus).
@MainActor
@Observable
public final class StoresViewModel {
    public private(set) var stores: [Store] = []
    public private(set) var settings: OptimizationSettings = .default
    public private(set) var state: LoadState = .idle
    public var actionError: String?

    private let dependencies: AppDependencies

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    public var includedCount: Int { stores.filter(\.isIncluded).count }

    public func load() async {
        if stores.isEmpty { state = .loading }
        do {
            stores = try await dependencies.stores.allStores()
            settings = try await dependencies.settings.settings()
            state = .loaded
        } catch {
            state = .failed(error.userMessage)
        }
    }

    public func isOpenNow(_ store: Store) -> Bool? {
        store.isOpen(at: dependencies.now())
    }

    public func setIncluded(_ store: Store, _ included: Bool) async {
        var updated = store
        updated.isIncluded = included
        await save(updated)
    }

    public func setFavorite(_ store: Store, _ favorite: Bool) async {
        var updated = store
        updated.isFavorite = favorite
        await save(updated)
    }

    public func save(_ store: Store) async {
        do {
            try await dependencies.stores.save(store)
            await load()
        } catch {
            actionError = error.userMessage
        }
    }

    public func delete(_ store: Store) async {
        do {
            try await dependencies.stores.deleteStore(id: store.id)
            await load()
        } catch {
            actionError = error.userMessage
        }
    }

    /// Vorlage für einen neuen Laden der gewählten Kette.
    public func newStoreTemplate(chain: StoreChain) -> Store {
        Store(
            id: "store-\(UUID().uuidString.lowercased())",
            chain: chain,
            name: chain == .other ? "" : chain.displayName,
            openingHours: OpeningPeriod.mondayToSaturday(from: (7, 0), to: (21, 0)),
            isIncluded: true
        )
    }

    // MARK: Einstellungen

    public func setStoreLimit(_ limit: StoreLimit) async {
        var updated = settings
        updated.storeLimit = limit
        await save(updated)
    }

    public func setMode(_ mode: OptimizationMode) async {
        var updated = settings
        updated.mode = mode
        await save(updated)
    }

    public func save(_ newSettings: OptimizationSettings) async {
        let previous = settings
        settings = newSettings
        do {
            try await dependencies.settings.save(newSettings)
        } catch {
            settings = previous
            actionError = error.userMessage
        }
    }

    public var canResetSampleData: Bool { dependencies.resetToSampleData != nil }

    public func resetSampleData() async {
        guard let reset = dependencies.resetToSampleData else { return }
        do {
            try await reset()
            await load()
        } catch {
            actionError = error.userMessage
        }
    }
}
