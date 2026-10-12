import Foundation

/// Maximale Anzahl zu besuchender Läden.
public enum StoreLimit: Hashable, Codable, Sendable, CaseIterable, Identifiable {
    case one
    case two
    case three
    case unlimited

    public var id: String { displayName }

    public var maxCount: Int? {
        switch self {
        case .one: return 1
        case .two: return 2
        case .three: return 3
        case .unlimited: return nil
        }
    }

    public var displayName: String {
        switch self {
        case .one: return "1 Laden"
        case .two: return "2 Läden"
        case .three: return "3 Läden"
        case .unlimited: return "Unbegrenzt"
        }
    }
}

/// Optimierungsmodus.
public enum OptimizationMode: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Günstigster Gesamtpreis über alle aktivierten Läden (ohne Ladenlimit).
    case cheapestOverall
    /// Günstigster Gesamtpreis bei maximal X Läden (X aus `StoreLimit`).
    case cheapestWithStoreLimit
    /// Günstigste Lösung mit genau einem Laden.
    case singleStore
    /// Bester Kompromiss aus Preis und Wegstrecke (unter Beachtung des Ladenlimits).
    case balanced

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .cheapestOverall: return "Günstigster Gesamtpreis"
        case .cheapestWithStoreLimit: return "Günstigster Preis mit Ladenlimit"
        case .singleStore: return "Nur ein Laden"
        case .balanced: return "Kompromiss Preis & Weg"
        }
    }
}

/// Einstellungen für die Berechnung.
public struct OptimizationSettings: Hashable, Codable, Sendable {
    public var mode: OptimizationMode
    public var storeLimit: StoreLimit
    /// Bewertung eines zusätzlichen Kilometers Weg im Kompromiss-Modus.
    public var costPerKilometer: Money
    /// Nur aktuell geöffnete Läden berücksichtigen.
    public var onlyOpenStores: Bool
    /// Ab wie vielen Tagen vor Ablauf ein Angebot als „läuft bald ab“ gilt.
    public var offerExpiryWarningDays: Int
    /// Startpunkt für die Wegberechnung (optional).
    public var homeLocation: GeoPoint?

    public init(
        mode: OptimizationMode = .cheapestWithStoreLimit,
        storeLimit: StoreLimit = .two,
        costPerKilometer: Money = Money(cents: 30),
        onlyOpenStores: Bool = false,
        offerExpiryWarningDays: Int = 2,
        homeLocation: GeoPoint? = nil
    ) {
        self.mode = mode
        self.storeLimit = storeLimit
        self.costPerKilometer = costPerKilometer
        self.onlyOpenStores = onlyOpenStores
        self.offerExpiryWarningDays = offerExpiryWarningDays
        self.homeLocation = homeLocation
    }

    public static let `default` = OptimizationSettings()

    /// Effektives Ladenlimit für den gewählten Modus.
    public var effectiveStoreLimit: Int? {
        switch mode {
        case .cheapestOverall: return nil
        case .singleStore: return 1
        case .cheapestWithStoreLimit, .balanced: return storeLimit.maxCount
        }
    }
}
