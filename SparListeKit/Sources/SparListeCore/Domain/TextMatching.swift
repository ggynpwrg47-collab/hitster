import Foundation

/// Normalisierung für robuste, sprachfreundliche Textvergleiche
/// (Groß-/Kleinschreibung, Umlaute, Satzzeichen).
public enum TextMatching {
    private static let locale = Locale(identifier: "de_DE")

    public static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
        let cleaned = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(cleaned)
            .split(separator: " ")
            .joined(separator: " ")
    }

    public static func tokens(_ text: String) -> [String] {
        normalize(text).split(separator: " ").map(String.init)
    }

    /// Alle Wörter von `query` kommen (als Wortanfang) in `haystack` vor.
    public static func matchesAllTokens(query: String, in haystack: String) -> Bool {
        let queryTokens = tokens(query)
        guard !queryTokens.isEmpty else { return false }
        let haystackTokens = tokens(haystack)
        let joined = haystackTokens.joined(separator: " ")
        return queryTokens.allSatisfy { token in
            haystackTokens.contains { $0.hasPrefix(token) } || joined.contains(token)
        }
    }
}

/// Ordnet Listeneinträge den Katalogprodukten zu.
public struct ProductMatcher: Sendable {
    public var catalog: Catalog

    public init(catalog: Catalog) {
        self.catalog = catalog
    }

    /// Suchtext eines Produkts: Name, allgemeiner Name, Marke, Suchbegriffe.
    public func searchText(for product: Product) -> String {
        let brandName = catalog.brand(id: product.brandID)?.name ?? ""
        return ([product.name, product.genericName, brandName] + product.keywords).joined(separator: " ")
    }

    /// Alle Produkte, die zum Suchbegriff des Eintrags passen.
    /// Exakte Treffer auf den allgemeinen Namen haben Vorrang vor Teiltreffern,
    /// damit „Milch“ nicht ungewollt „Milchreis“ einschließt, sofern es echte Milch-Treffer gibt.
    public func candidates(for query: String) -> [Product] {
        let normalizedQuery = TextMatching.normalize(query)
        guard !normalizedQuery.isEmpty else { return [] }
        let exact = catalog.products.filter { TextMatching.normalize($0.genericName) == normalizedQuery }
        if !exact.isEmpty { return exact }
        return catalog.products.filter { TextMatching.matchesAllTokens(query: query, in: searchText(for: $0)) }
    }

    /// Prüft, ob das Produkt eine der ausgeschlossenen Zutaten enthält.
    public func containsExcludedIngredient(_ product: Product, excluded: [String]) -> Bool {
        let normalizedExcluded = excluded.map(TextMatching.normalize).filter { !$0.isEmpty }
        guard !normalizedExcluded.isEmpty else { return false }
        let ingredients = product.ingredients.map(TextMatching.normalize)
        return normalizedExcluded.contains { excludedIngredient in
            ingredients.contains { $0.contains(excludedIngredient) }
        }
    }
}
