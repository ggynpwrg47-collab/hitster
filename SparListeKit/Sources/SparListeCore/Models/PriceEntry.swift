import Foundation

/// Herkunft eines Preises. Wird für die Transparenzkennzeichnung genutzt.
public enum PriceSource: String, Codable, CaseIterable, Sendable {
    /// Lokal mitgelieferte, erfundene Beispieldaten.
    case sampleData
    /// Vom Nutzer manuell erfasst (z. B. Kassenbon, Regal).
    case manualEntry
    /// Aus einer Datei importiert.
    case imported
    /// Geschätzter Preis (z. B. aus Erfahrungswerten abgeleitet).
    case estimate

    public var displayName: String {
        switch self {
        case .sampleData: return "Beispieldaten"
        case .manualEntry: return "Manuell erfasst"
        case .imported: return "Importiert"
        case .estimate: return "Schätzung"
        }
    }
}

/// Verfügbarkeit eines Artikels in einem Laden.
public enum Availability: String, Codable, CaseIterable, Sendable {
    case available
    case limited
    case unavailable

    public var displayName: String {
        switch self {
        case .available: return "Verfügbar"
        case .limited: return "Begrenzt verfügbar"
        case .unavailable: return "Nicht verfügbar"
        }
    }

    public var isPurchasable: Bool { self != .unavailable }
}

/// Art des Preises: regulärer Preis oder zeitlich begrenzter Aktionspreis.
public enum PriceKind: Hashable, Codable, Sendable {
    case regular
    /// Gültig von `validFrom` (Tagesbeginn) bis einschließlich `validUntil` (Tagesende).
    case offer(validFrom: Date, validUntil: Date)

    public var isOffer: Bool {
        if case .offer = self { return true }
        return false
    }
}

/// Ein Preis für ein Produkt in einem Laden.
public struct PriceEntry: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var productID: String
    public var storeID: String
    public var price: Money
    public var kind: PriceKind
    public var availability: Availability
    public var source: PriceSource
    /// Zeitpunkt, zu dem der Preis erfasst bzw. zuletzt bestätigt wurde.
    public var observedAt: Date

    public init(
        id: String,
        productID: String,
        storeID: String,
        price: Money,
        kind: PriceKind = .regular,
        availability: Availability = .available,
        source: PriceSource,
        observedAt: Date
    ) {
        self.id = id
        self.productID = productID
        self.storeID = storeID
        self.price = price
        self.kind = kind
        self.availability = availability
        self.source = source
        self.observedAt = observedAt
    }

    public var isOffer: Bool { kind.isOffer }

    public var offerValidUntil: Date? {
        if case let .offer(_, until) = kind { return until }
        return nil
    }
}

/// Aktualität eines Preises, wie sie in der UI gekennzeichnet wird.
public enum PriceFreshness: String, Codable, Sendable, Comparable {
    case current
    case estimated
    case outdated

    public var displayName: String {
        switch self {
        case .current: return "Aktuell"
        case .estimated: return "Geschätzt"
        case .outdated: return "Veraltet"
        }
    }

    private var rank: Int {
        switch self {
        case .current: return 0
        case .estimated: return 1
        case .outdated: return 2
        }
    }

    public static func < (lhs: PriceFreshness, rhs: PriceFreshness) -> Bool { lhs.rank < rhs.rank }
}
