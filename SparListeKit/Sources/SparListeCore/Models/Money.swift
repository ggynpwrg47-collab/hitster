import Foundation

/// Geldbetrag in Euro-Cent. Ganzzahlig, damit Summen exakt bleiben.
public struct Money: Hashable, Comparable, Codable, Sendable {
    public var cents: Int

    public init(cents: Int) {
        self.cents = cents
    }

    /// Bequemer Initialisierer für Beispieldaten und Tests, z. B. `Money(euros: 1.19)`.
    public init(euros: Double) {
        self.cents = Int((euros * 100).rounded())
    }

    public static let zero = Money(cents: 0)

    public var euros: Double { Double(cents) / 100 }

    public static func + (lhs: Money, rhs: Money) -> Money { Money(cents: lhs.cents + rhs.cents) }
    public static func - (lhs: Money, rhs: Money) -> Money { Money(cents: lhs.cents - rhs.cents) }
    public static func * (lhs: Money, rhs: Int) -> Money { Money(cents: lhs.cents * rhs) }
    public static func += (lhs: inout Money, rhs: Money) { lhs.cents += rhs.cents }
    public static func < (lhs: Money, rhs: Money) -> Bool { lhs.cents < rhs.cents }

    /// Deutsche Darstellung, z. B. „12,34 €“. Bewusst ohne `NumberFormatter`,
    /// damit die Ausgabe auf allen Plattformen identisch und testbar ist.
    public var formatted: String {
        let sign = cents < 0 ? "-" : ""
        let absolute = abs(cents)
        let euroPart = absolute / 100
        let centPart = absolute % 100
        return "\(sign)\(Money.groupThousands(euroPart)),\(centPart < 10 ? "0" : "")\(centPart) €"
    }

    static func groupThousands(_ value: Int) -> String {
        let digits = String(value)
        var result = ""
        for (index, character) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 {
                result.append(".")
            }
            result.append(character)
        }
        return result
    }
}

public extension Collection where Element == Money {
    func sum() -> Money { reduce(.zero, +) }
}
