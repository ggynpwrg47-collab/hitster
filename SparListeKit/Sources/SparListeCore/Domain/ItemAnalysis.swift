import Foundation

/// Eine konkrete Kaufoption: Produkt X in Laden Y, inklusive benötigter Packungsanzahl.
public struct StoreOption: Hashable, Sendable {
    public var storeID: String
    public var product: Product
    public var brand: Brand?
    public var resolvedPrice: ResolvedPrice
    public var packageCount: Int
    public var unitPrice: UnitPrice?
    public var offerEndsSoon: Bool

    public var packagePrice: Money { resolvedPrice.price }
    public var lineTotal: Money { resolvedPrice.price * packageCount }
    public var isOffer: Bool { resolvedPrice.isOffer }
    public var regularPrice: Money? { resolvedPrice.regularPrice }
    public var offerValidUntil: Date? { resolvedPrice.entry.offerValidUntil }
    public var freshness: PriceFreshness { resolvedPrice.freshness }
    public var source: PriceSource { resolvedPrice.entry.source }

    /// Sortierung „günstiger zuerst“: Gesamtkosten, dann Einheitspreis, dann IDs.
    static func isBetter(_ lhs: StoreOption, _ rhs: StoreOption) -> Bool {
        if lhs.lineTotal != rhs.lineTotal { return lhs.lineTotal < rhs.lineTotal }
        let lu = lhs.unitPrice?.centsPerBasis ?? .infinity
        let ru = rhs.unitPrice?.centsPerBasis ?? .infinity
        if lu != ru { return lu < ru }
        if lhs.product.id != rhs.product.id { return lhs.product.id < rhs.product.id }
        return lhs.storeID < rhs.storeID
    }
}

/// Hinweise zu einem Listeneintrag, die in der Ergebnisanzeige erscheinen.
public enum ItemIssue: Hashable, Sendable {
    /// Kein Katalogprodukt passt zum Suchbegriff.
    case noMatchingProduct
    /// Alle passenden Produkte wurden durch Marken- oder Zutatenausschlüsse entfernt.
    case allCandidatesExcluded
    /// Passende Produkte gibt es, aber in keinem berücksichtigten Laden (mit gültigem Preis).
    case notAvailableInIncludedStores
    /// Die gewünschte Marke ist in keinem berücksichtigten Laden verfügbar.
    case requiredBrandUnavailable(brandName: String)
    /// Die Wunschmarke fehlt; mit Erlaubnis wurde eine Alternative eingeplant.
    case brandSubstituted(brandName: String)
    case noOrganicVariantAvailable
    case noPrivateLabelVariantAvailable

    public var message: String {
        switch self {
        case .noMatchingProduct:
            return "Kein passendes Produkt im Katalog gefunden."
        case .allCandidatesExcluded:
            return "Alle passenden Produkte sind durch ausgeschlossene Marken oder Zutaten herausgefiltert."
        case .notAvailableInIncludedStores:
            return "In keinem der berücksichtigten Läden verfügbar."
        case let .requiredBrandUnavailable(brandName):
            return "Wunschmarke „\(brandName)“ ist in keinem berücksichtigten Laden verfügbar."
        case let .brandSubstituted(brandName):
            return "Wunschmarke „\(brandName)“ nicht verfügbar – Alternative eingeplant."
        case .noOrganicVariantAvailable:
            return "Keine Bio-Variante verfügbar – konventionelle Variante verwendet."
        case .noPrivateLabelVariantAvailable:
            return "Keine Eigenmarke verfügbar – Herstellermarke verwendet."
        }
    }

    /// Führt dazu, dass der Eintrag nicht eingeplant werden kann.
    public var blocksPurchase: Bool {
        switch self {
        case .noMatchingProduct, .allCandidatesExcluded, .notAvailableInIncludedStores, .requiredBrandUnavailable:
            return true
        case .brandSubstituted, .noOrganicVariantAvailable, .noPrivateLabelVariantAvailable:
            return false
        }
    }
}

/// Ergebnis der Analyse eines Listeneintrags über alle berücksichtigten Läden.
public struct ItemAnalysis: Hashable, Sendable {
    public var item: ShoppingListItem
    /// Beste Option je Laden (Schlüssel: Store-ID), nach allen Filtern und Vorgaben.
    public var bestOptionByStore: [String: StoreOption]
    public var issues: [ItemIssue]
    /// Alternativvorschläge (z. B. wenn die Wunschmarke fehlt), günstigster Einheitspreis zuerst.
    public var alternatives: [StoreOption]
    /// Bedarf, auf den sich die Packungsanzahl bezieht.
    public var requiredAmount: Quantity?

    public var isPurchasable: Bool { !bestOptionByStore.isEmpty }
}

/// Analysiert Listeneinträge: Zuordnung, Filter, Markenvorgaben, Präferenzen, Preise je Laden.
public struct ItemAnalyzer: Sendable {
    public var catalog: Catalog
    public var resolver: PriceResolver
    public var offerExpiryWarningDays: Int

    private let matcher: ProductMatcher

    public init(catalog: Catalog, resolver: PriceResolver = PriceResolver(), offerExpiryWarningDays: Int = 2) {
        self.catalog = catalog
        self.resolver = resolver
        self.offerExpiryWarningDays = offerExpiryWarningDays
        self.matcher = ProductMatcher(catalog: catalog)
    }

    public func analyze(_ item: ShoppingListItem, stores: [Store], prices: [PriceEntry], at date: Date) -> ItemAnalysis {
        var issues: [ItemIssue] = []

        // 1. Zuordnung über den Suchbegriff.
        let matched = matcher.candidates(for: item.query)
        guard !matched.isEmpty else {
            return ItemAnalysis(item: item, bestOptionByStore: [:], issues: [.noMatchingProduct], alternatives: [], requiredAmount: nil)
        }

        // 2. Harte Ausschlüsse (Marken, Zutaten).
        var products = matched.filter { product in
            if let brandID = product.brandID, item.excludedBrandIDs.contains(brandID) { return false }
            return !matcher.containsExcludedIngredient(product, excluded: item.excludedIngredients)
        }
        guard !products.isEmpty else {
            return ItemAnalysis(item: item, bestOptionByStore: [:], issues: [.allCandidatesExcluded], alternatives: [], requiredAmount: nil)
        }

        // 3. Vergleichbarkeit: Bedarf in einer gemeinsamen Dimension bestimmen.
        let required = requiredAmount(for: item, products: products)
        products = products.filter { $0.packageSize.isComparable(to: required) }

        // 4. Kaufoptionen in allen berücksichtigten Läden.
        let storeIDs = Set(stores.map(\.id))
        let productIDs = Set(products.map(\.id))
        let relevantPrices = prices.filter { storeIDs.contains($0.storeID) && productIDs.contains($0.productID) }
        let grouped = Dictionary(grouping: relevantPrices) { PriceKey(productID: $0.productID, storeID: $0.storeID) }
        let productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        var options: [StoreOption] = []
        for (key, entries) in grouped {
            guard let product = productsByID[key.productID],
                  let resolved = resolver.resolve(entries, at: date),
                  let packages = UnitPricing.packagesNeeded(toCover: required, with: product.packageSize) else {
                continue
            }
            options.append(StoreOption(
                storeID: key.storeID,
                product: product,
                brand: catalog.brand(id: product.brandID),
                resolvedPrice: resolved,
                packageCount: packages,
                unitPrice: UnitPricing.unitPrice(price: resolved.price, packageSize: product.packageSize),
                offerEndsSoon: resolved.isOffer && resolver.validity.endsSoon(resolved.entry, at: date, withinDays: offerExpiryWarningDays)
            ))
        }
        options.sort(by: StoreOption.isBetter)

        guard !options.isEmpty else {
            return ItemAnalysis(item: item, bestOptionByStore: [:], issues: [.notAvailableInIncludedStores], alternatives: [], requiredAmount: required)
        }

        // 5. Markenvorgabe hat Vorrang vor dem günstigsten Preis.
        var alternatives: [StoreOption] = []
        if let brandID = item.requiredBrandID {
            let brandName = catalog.brand(id: brandID)?.name ?? brandID
            let brandOptions = options.filter { $0.product.brandID == brandID }
            if brandOptions.isEmpty {
                alternatives = Self.alternativeSuggestions(from: options)
                if item.allowsBrandSubstitution {
                    issues.append(.brandSubstituted(brandName: brandName))
                } else {
                    issues.append(.requiredBrandUnavailable(brandName: brandName))
                    return ItemAnalysis(item: item, bestOptionByStore: [:], issues: issues, alternatives: alternatives, requiredAmount: required)
                }
            } else {
                options = brandOptions
            }
        }

        // 6. Weiche Präferenzen: anwenden, wenn mindestens eine passende Variante verfügbar ist.
        if item.prefersOrganic {
            let organic = options.filter { $0.product.isOrganic }
            if organic.isEmpty { issues.append(.noOrganicVariantAvailable) } else { options = organic }
        }
        if item.prefersPrivateLabel {
            let privateLabel = options.filter { $0.brand?.isPrivateLabel == true }
            if privateLabel.isEmpty { issues.append(.noPrivateLabelVariantAvailable) } else { options = privateLabel }
        }

        // 7. Beste Option je Laden.
        var best: [String: StoreOption] = [:]
        for option in options where best[option.storeID] == nil {
            best[option.storeID] = option // `options` ist bereits sortiert.
        }
        return ItemAnalysis(item: item, bestOptionByStore: best, issues: issues, alternatives: alternatives, requiredAmount: required)
    }

    /// Bedarf des Eintrags. Ohne gewünschte Packungsgröße gilt:
    /// Menge × häufigste Packungsgröße der passenden Produkte (bei Gleichstand die kleinere).
    func requiredAmount(for item: ShoppingListItem, products: [Product]) -> Quantity {
        if let desired = item.desiredPackageSize {
            return Quantity(desired.value * Double(item.quantity), desired.unit)
        }
        let dimensionCounts = Dictionary(grouping: products, by: { $0.packageSize.dimension }).mapValues(\.count)
        let dimension = dimensionCounts.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key.rawValue > rhs.key.rawValue
        }?.key ?? .count
        let sizes = products.filter { $0.packageSize.dimension == dimension }.map { $0.packageSize.baseValue }
        let sizeCounts = Dictionary(grouping: sizes, by: { $0 }).mapValues(\.count)
        let modal = sizeCounts.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key > rhs.key
        }?.key ?? 1
        let baseUnit: MeasureUnit = dimension == .mass ? .gram : (dimension == .volume ? .milliliter : .piece)
        return Quantity(modal * Double(item.quantity), baseUnit)
    }

    /// Bis zu drei Alternativen mit unterschiedlichen Produkten, günstigster Einheitspreis zuerst.
    static func alternativeSuggestions(from options: [StoreOption]) -> [StoreOption] {
        let sorted = options.sorted { lhs, rhs in
            let lu = lhs.unitPrice?.centsPerBasis ?? .infinity
            let ru = rhs.unitPrice?.centsPerBasis ?? .infinity
            return lu != ru ? lu < ru : StoreOption.isBetter(lhs, rhs)
        }
        var seen = Set<String>()
        var result: [StoreOption] = []
        for option in sorted where !seen.contains(option.product.id) {
            seen.insert(option.product.id)
            result.append(option)
            if result.count == 3 { break }
        }
        return result
    }
}

private struct PriceKey: Hashable {
    var productID: String
    var storeID: String
}
