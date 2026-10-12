import Foundation

/// Vorschlag für die Autovervollständigung beim Hinzufügen eines Produkts.
public struct ProductSuggestion: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// Allgemeines Produkt, z. B. „Laktosefreie Milch“.
        case generic
        /// Markenspezifisch, z. B. „Laktosefreie Milch“ von „MinusL“.
        case branded(brandID: String, brandName: String)
    }

    public var id: String {
        switch kind {
        case .generic: return "g|\(genericName)"
        case let .branded(brandID, _): return "b|\(genericName)|\(brandID)"
        }
    }

    public var genericName: String
    public var kind: Kind
    /// Typische Packungsgröße (häufigste Größe der passenden Produkte).
    public var typicalPackageSize: Quantity?

    public var title: String {
        switch kind {
        case .generic: return genericName
        case let .branded(_, brandName): return "\(genericName) – \(brandName)"
        }
    }

    public var brandID: String? {
        if case let .branded(id, _) = kind { return id }
        return nil
    }
}

/// Autovervollständigung über den lokalen Katalog.
public struct ProductSuggestionService: Sendable {
    public var catalog: Catalog

    public init(catalog: Catalog) {
        self.catalog = catalog
    }

    /// Liefert Vorschläge: zuerst allgemeine Produkte, deren Name mit der Eingabe beginnt,
    /// dann Teiltreffer, danach markenspezifische Varianten.
    public func suggestions(for input: String, limit: Int = 8) -> [ProductSuggestion] {
        let query = TextMatching.normalize(input)
        guard !query.isEmpty else { return [] }
        let matcher = ProductMatcher(catalog: catalog)

        var genericScores: [String: Int] = [:]
        var branded: [String: (score: Int, suggestion: ProductSuggestion)] = [:]
        let byGeneric = Dictionary(grouping: catalog.products, by: \.genericName)

        for (genericName, products) in byGeneric {
            let normalizedGeneric = TextMatching.normalize(genericName)
            let typical = Self.typicalSize(products)
            var genericScore: Int?
            if normalizedGeneric.hasPrefix(query) {
                genericScore = 0
            } else if normalizedGeneric.split(separator: " ").contains(where: { $0.hasPrefix(query) }) {
                genericScore = 1
            } else if products.contains(where: { TextMatching.matchesAllTokens(query: input, in: matcher.searchText(for: $0)) }) {
                genericScore = 3
            }
            if let genericScore { genericScores[genericName] = genericScore }

            for product in products {
                guard let brand = catalog.brand(id: product.brandID) else { continue }
                let brandNormalized = TextMatching.normalize(brand.name)
                let haystack = matcher.searchText(for: product)
                let score: Int
                if brandNormalized.hasPrefix(query) {
                    score = 2
                } else if genericScore != nil || TextMatching.matchesAllTokens(query: input, in: haystack) {
                    score = 4
                } else {
                    continue
                }
                let suggestion = ProductSuggestion(
                    genericName: genericName,
                    kind: .branded(brandID: brand.id, brandName: brand.name),
                    typicalPackageSize: typical
                )
                if let existing = branded[suggestion.id], existing.score <= score { continue }
                branded[suggestion.id] = (score, suggestion)
            }
        }

        var scored: [(Int, ProductSuggestion)] = genericScores.map { name, score in
            (score, ProductSuggestion(genericName: name, kind: .generic, typicalPackageSize: Self.typicalSize(byGeneric[name] ?? [])))
        }
        scored += branded.values.map { ($0.score, $0.suggestion) }
        scored.sort { lhs, rhs in
            lhs.0 != rhs.0 ? lhs.0 < rhs.0 : lhs.1.title.localizedCaseInsensitiveCompare(rhs.1.title) == .orderedAscending
        }
        return Array(scored.prefix(limit).map(\.1))
    }

    /// Marken, die für einen allgemeinen Produktnamen im Katalog vorkommen.
    public func brands(forGenericName genericName: String) -> [Brand] {
        let brandIDs = Set(ProductMatcher(catalog: catalog).candidates(for: genericName).compactMap(\.brandID))
        return catalog.brands
            .filter { brandIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func typicalSize(_ products: [Product]) -> Quantity? {
        let counts = Dictionary(grouping: products.map(\.packageSize), by: { $0 }).mapValues(\.count)
        return counts.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key.baseValue > rhs.key.baseValue
        }?.key
    }
}
