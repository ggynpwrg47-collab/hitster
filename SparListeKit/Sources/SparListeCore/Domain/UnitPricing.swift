import Foundation

/// Bezugsgröße für Einheitspreise (Grundpreise).
public enum UnitPriceBasis: String, Codable, Sendable {
    case perKilogram
    case per100Gram
    case perLiter
    case per100Milliliter
    case perPiece

    /// Bezugsmenge in der Basiseinheit der Dimension.
    public var baseAmount: Double {
        switch self {
        case .perKilogram, .perLiter: return 1000
        case .per100Gram, .per100Milliliter: return 100
        case .perPiece: return 1
        }
    }

    public var dimension: MeasureDimension {
        switch self {
        case .perKilogram, .per100Gram: return .mass
        case .perLiter, .per100Milliliter: return .volume
        case .perPiece: return .count
        }
    }

    public var label: String {
        switch self {
        case .perKilogram: return "1 kg"
        case .per100Gram: return "100 g"
        case .perLiter: return "1 l"
        case .per100Milliliter: return "100 ml"
        case .perPiece: return "Stk."
        }
    }

    /// Standardbezug je Dimension (entspricht der in Deutschland üblichen Grundpreisangabe).
    public static func standard(for dimension: MeasureDimension) -> UnitPriceBasis {
        switch dimension {
        case .mass: return .perKilogram
        case .volume: return .perLiter
        case .count: return .perPiece
        }
    }
}

/// Einheitspreis, z. B. „1,19 € / 1 l“. Intern als (gebrochene) Cent-Zahl,
/// damit Vergleiche nicht durch Rundung verfälscht werden.
public struct UnitPrice: Hashable, Comparable, Codable, Sendable {
    public var centsPerBasis: Double
    public var basis: UnitPriceBasis

    public init(centsPerBasis: Double, basis: UnitPriceBasis) {
        self.centsPerBasis = centsPerBasis
        self.basis = basis
    }

    public static func < (lhs: UnitPrice, rhs: UnitPrice) -> Bool {
        lhs.centsPerBasis < rhs.centsPerBasis
    }

    /// Gerundet auf ganze Cent.
    public var rounded: Money { Money(cents: Int(centsPerBasis.rounded())) }

    public var formatted: String { "\(rounded.formatted) / \(basis.label)" }
}

public enum UnitPricing {
    /// Berechnet den Einheitspreis eines Preises für eine Packungsgröße.
    /// Liefert `nil`, wenn Dimension und Bezugsgröße nicht zusammenpassen oder die Größe 0 ist.
    public static func unitPrice(price: Money, packageSize: Quantity, basis: UnitPriceBasis? = nil) -> UnitPrice? {
        let basis = basis ?? UnitPriceBasis.standard(for: packageSize.dimension)
        guard basis.dimension == packageSize.dimension, packageSize.baseValue > 0 else { return nil }
        let cents = Double(price.cents) / packageSize.baseValue * basis.baseAmount
        return UnitPrice(centsPerBasis: cents, basis: basis)
    }

    /// Wie viele Packungen der Größe `packageSize` nötig sind, um `required` zu decken.
    /// Liefert `nil` bei inkompatiblen Dimensionen.
    public static func packagesNeeded(toCover required: Quantity, with packageSize: Quantity) -> Int? {
        guard required.isComparable(to: packageSize), packageSize.baseValue > 0 else { return nil }
        let ratio = required.baseValue / packageSize.baseValue
        // Kleine Toleranz gegen Gleitkomma-Artefakte (z. B. 3 × 0,333 l).
        return max(1, Int((ratio - 1e-9).rounded(.up)))
    }
}
