import Foundation

/// Physikalische Dimension einer Packungsgröße. Nur Mengen derselben
/// Dimension sind miteinander vergleichbar.
public enum MeasureDimension: String, Codable, Sendable {
    case mass
    case volume
    case count
}

/// Einheit einer Packungsgröße.
public enum MeasureUnit: String, Codable, CaseIterable, Sendable {
    case gram = "g"
    case kilogram = "kg"
    case milliliter = "ml"
    case liter = "l"
    case piece = "Stk."

    public var dimension: MeasureDimension {
        switch self {
        case .gram, .kilogram: return .mass
        case .milliliter, .liter: return .volume
        case .piece: return .count
        }
    }

    /// Faktor zur Basiseinheit der Dimension (g, ml, Stück).
    public var baseFactor: Double {
        switch self {
        case .gram, .milliliter, .piece: return 1
        case .kilogram, .liter: return 1000
        }
    }

    public var symbol: String { rawValue }
}

/// Eine Menge mit Einheit, z. B. 500 g oder 1,5 l.
public struct Quantity: Hashable, Codable, Sendable {
    public var value: Double
    public var unit: MeasureUnit

    public init(_ value: Double, _ unit: MeasureUnit) {
        self.value = value
        self.unit = unit
    }

    public var dimension: MeasureDimension { unit.dimension }

    /// Menge in der Basiseinheit (g, ml oder Stück).
    public var baseValue: Double { value * unit.baseFactor }

    public func isComparable(to other: Quantity) -> Bool {
        dimension == other.dimension
    }

    /// Lesbare Darstellung, z. B. „500 g“, „1,5 l“, „10 Stk.“.
    public var formatted: String {
        "\(Quantity.formatNumber(value)) \(unit.symbol)"
    }

    static func formatNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        let rounded = (value * 100).rounded() / 100
        var text = String(rounded)
        if text.hasSuffix("0") && text.contains(".") { text.removeLast() }
        return text.replacingOccurrences(of: ".", with: ",")
    }
}
