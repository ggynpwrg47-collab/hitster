import Foundation

/// Supermarktkette. Dient als Kategorie für Läden und zur Zuordnung von Eigenmarken.
public enum StoreChain: String, Codable, CaseIterable, Sendable, Identifiable {
    case rewe
    case edeka
    case aldi
    case lidl
    case kaufland
    case netto
    case penny
    case marktkauf
    case globus
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .rewe: return "REWE"
        case .edeka: return "EDEKA"
        case .aldi: return "Aldi"
        case .lidl: return "Lidl"
        case .kaufland: return "Kaufland"
        case .netto: return "Netto"
        case .penny: return "Penny"
        case .marktkauf: return "Marktkauf"
        case .globus: return "Globus"
        case .other: return "Sonstiger Laden"
        }
    }
}

/// Marke bzw. Hersteller. Eigenmarken sind einer Kette zugeordnet.
public struct Brand: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    /// Kette, deren Eigenmarke dies ist (`nil` = Herstellermarke).
    public var privateLabelOf: StoreChain?

    public init(id: String, name: String, privateLabelOf: StoreChain? = nil) {
        self.id = id
        self.name = name
        self.privateLabelOf = privateLabelOf
    }

    public var isPrivateLabel: Bool { privateLabelOf != nil }
}

/// Ein konkretes, kaufbares Produkt (Artikel), z. B. „Ja! Laktosefreie Milch 1,5 % 1 l“.
public struct Product: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    /// Vollständiger Artikelname.
    public var name: String
    /// Allgemeine Produktbezeichnung, über die Listeneinträge zugeordnet werden,
    /// z. B. „Laktosefreie Milch“.
    public var genericName: String
    public var brandID: String?
    public var packageSize: Quantity
    public var isOrganic: Bool
    /// Zutaten bzw. Merkmale für Ausschlussfilter (z. B. „Palmöl“, „Gluten“).
    public var ingredients: [String]
    /// Zusätzliche Suchbegriffe für die Zuordnung und Autovervollständigung.
    public var keywords: [String]
    public var category: String

    public init(
        id: String,
        name: String,
        genericName: String,
        brandID: String? = nil,
        packageSize: Quantity,
        isOrganic: Bool = false,
        ingredients: [String] = [],
        keywords: [String] = [],
        category: String = "Sonstiges"
    ) {
        self.id = id
        self.name = name
        self.genericName = genericName
        self.brandID = brandID
        self.packageSize = packageSize
        self.isOrganic = isOrganic
        self.ingredients = ingredients
        self.keywords = keywords
        self.category = category
    }
}

/// Snapshot des Produktkatalogs (Produkte und Marken) für die Domänenlogik.
public struct Catalog: Hashable, Codable, Sendable {
    public var products: [Product]
    public var brands: [Brand]

    public init(products: [Product] = [], brands: [Brand] = []) {
        self.products = products
        self.brands = brands
    }

    public func brand(id: String?) -> Brand? {
        guard let id else { return nil }
        return brands.first { $0.id == id }
    }

    public func product(id: String) -> Product? {
        products.first { $0.id == id }
    }
}
