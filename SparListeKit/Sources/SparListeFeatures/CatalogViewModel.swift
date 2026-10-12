import Foundation
import Observation
import SparListeCore

/// Produkt- und Preispflege (lokale Datenquelle).
@MainActor
@Observable
public final class CatalogViewModel {
    public private(set) var catalog = Catalog()
    public private(set) var prices: [PriceEntry] = []
    public private(set) var stores: [Store] = []
    public private(set) var state: LoadState = .idle
    public var actionError: String?
    public var infoMessage: String?
    public var searchText = ""

    private let dependencies: AppDependencies

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    public var sourceDescriptor: DataSourceDescriptor { dependencies.prices.descriptor }

    public func load() async {
        if catalog.products.isEmpty { state = .loading }
        do {
            catalog = try await dependencies.catalog.catalog()
            prices = try await dependencies.prices.allPriceEntries()
            stores = try await dependencies.stores.allStores()
            state = .loaded
        } catch {
            state = .failed(error.userMessage)
        }
    }

    /// Produkte gruppiert nach allgemeinem Namen, gefiltert nach Suchtext.
    public var groupedProducts: [(genericName: String, products: [Product])] {
        let matcher = ProductMatcher(catalog: catalog)
        let filtered = searchText.isEmpty
            ? catalog.products
            : catalog.products.filter { TextMatching.matchesAllTokens(query: searchText, in: matcher.searchText(for: $0)) }
        return Dictionary(grouping: filtered, by: \.genericName)
            .map { (genericName: $0.key, products: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.genericName.localizedCaseInsensitiveCompare($1.genericName) == .orderedAscending }
    }

    public func brandName(for product: Product) -> String {
        catalog.brand(id: product.brandID)?.name ?? "Ohne Marke"
    }

    public func storeName(for id: String) -> String {
        stores.first { $0.id == id }?.name ?? "Unbekannter Laden"
    }

    public func prices(for product: Product) -> [PriceEntry] {
        prices.filter { $0.productID == product.id }.sorted { lhs, rhs in
            lhs.storeID != rhs.storeID ? storeName(for: lhs.storeID) < storeName(for: rhs.storeID) : lhs.observedAt > rhs.observedAt
        }
    }

    public func freshness(of entry: PriceEntry) -> PriceFreshness {
        PriceFreshnessPolicy().freshness(of: entry, at: dependencies.now())
    }

    public func isValid(_ entry: PriceEntry) -> Bool {
        OfferValidity().isValid(entry, at: dependencies.now())
    }

    public func newProductTemplate() -> Product {
        Product(id: "product-\(UUID().uuidString.lowercased())", name: "", genericName: "", packageSize: Quantity(1, .piece))
    }

    public func newPriceTemplate(for product: Product) -> PriceEntry {
        PriceEntry(
            id: "price-\(UUID().uuidString.lowercased())",
            productID: product.id,
            storeID: stores.first?.id ?? "",
            price: Money(cents: 0),
            source: .manualEntry,
            observedAt: dependencies.now()
        )
    }

    public func save(_ product: Product) async {
        await perform { try await self.dependencies.catalog.save(product) }
    }

    /// Legt eine neue Marke an (oder liefert eine bestehende mit gleichem Namen).
    public func brand(named name: String, privateLabelOf chain: StoreChain?) async -> Brand? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let existing = catalog.brands.first(where: { TextMatching.normalize($0.name) == TextMatching.normalize(trimmed) }) {
            return existing
        }
        let brand = Brand(id: "brand-\(UUID().uuidString.lowercased())", name: trimmed, privateLabelOf: chain)
        let saved = await perform { try await self.dependencies.catalog.save(brand) }
        return saved ? brand : nil
    }

    public func delete(_ product: Product) async {
        await perform { try await self.dependencies.catalog.deleteProduct(id: product.id) }
    }

    public func save(_ entry: PriceEntry) async {
        await perform { try await self.dependencies.prices.save(entry) }
    }

    public func delete(_ entry: PriceEntry) async {
        await perform { try await self.dependencies.prices.deletePriceEntry(id: entry.id) }
    }

    public var canImport: Bool { dependencies.importPriceFile != nil }

    public func importFile(_ data: Data) async {
        guard let importer = dependencies.importPriceFile else { return }
        do {
            let summary = try await importer(data)
            infoMessage = "Import abgeschlossen: \(summary.added) neu, \(summary.updated) aktualisiert."
            await load()
        } catch {
            actionError = error.userMessage
        }
    }

    @discardableResult
    private func perform(_ action: @escaping () async throws -> Void) async -> Bool {
        do {
            try await action()
            await load()
            return true
        } catch {
            actionError = error.userMessage
            return false
        }
    }
}
