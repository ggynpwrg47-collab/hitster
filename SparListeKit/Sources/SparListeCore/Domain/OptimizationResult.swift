import Foundation

/// Eine Position im Einkaufsplan: Listeneintrag → konkretes Produkt in einem Laden.
public struct PlanLine: Identifiable, Hashable, Sendable {
    public var id: UUID { item.id }
    public var item: ShoppingListItem
    public var option: StoreOption

    public var lineTotal: Money { option.lineTotal }
}

/// Ein Ladenbesuch im Einkaufsplan.
public struct PlanStop: Identifiable, Hashable, Sendable {
    public var id: String { store.id }
    public var store: Store
    public var lines: [PlanLine]

    public var subtotal: Money { lines.map(\.lineTotal).sum() }
}

/// Eine vollständige Einkaufsaufteilung.
public struct ShoppingPlan: Hashable, Sendable {
    /// Läden in empfohlener Reihenfolge.
    public var stops: [PlanStop]
    public var route: Route
    /// Einträge, die grundsätzlich erhältlich wären, aber nicht in den Läden dieser Variante.
    public var uncoveredItems: [ShoppingListItem]

    public var total: Money { stops.map(\.subtotal).sum() }
    public var storeCount: Int { stops.count }
    public var coveredItemCount: Int { stops.reduce(0) { $0 + $1.lines.count } }
    public var storeIDs: [String] { stops.map(\.store.id) }
    public var lines: [PlanLine] { stops.flatMap(\.lines) }

    /// Kosten des Eintrags in diesem Plan, falls enthalten.
    public func cost(of itemID: UUID) -> Money? {
        lines.first { $0.item.id == itemID }?.lineTotal
    }

    /// Gleiche Läden und gleiche Zuordnung?
    public func isEquivalent(to other: ShoppingPlan) -> Bool {
        Set(storeIDs) == Set(other.storeIDs)
            && Dictionary(uniqueKeysWithValues: lines.map { ($0.item.id, $0.option.storeID + $0.option.product.id) })
            == Dictionary(uniqueKeysWithValues: other.lines.map { ($0.item.id, $0.option.storeID + $0.option.product.id) })
    }
}

/// Alternative Variante, z. B. „Günstigste Variante mit 2 Läden“.
public struct PlanAlternative: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case bestWithStores(Int)
        case cheapestOverall
        case shortestRoute
        case balanced
    }

    public var id: String { title }
    /// Eine Variante kann mehrere Kriterien zugleich erfüllen.
    public var kinds: [Kind]
    public var plan: ShoppingPlan
    /// Entspricht diese Variante der Empfehlung?
    public var isSameAsRecommendation: Bool

    public var title: String {
        kinds.map(PlanAlternative.title(for:)).joined(separator: " · ")
    }

    public static func title(for kind: Kind) -> String {
        switch kind {
        case let .bestWithStores(count): return count == 1 ? "Günstigste Variante mit 1 Laden" : "Günstigste Variante mit \(count) Läden"
        case .cheapestOverall: return "Günstigster Gesamtpreis (alle Läden)"
        case .shortestRoute: return "Variante mit kürzester Gesamtwegstrecke"
        case .balanced: return "Kompromiss aus Preis und Weg"
        }
    }
}

/// Ersparnis der Empfehlung gegenüber der besten Ein-Laden-Lösung.
public struct SavingsSummary: Hashable, Sendable {
    public var referencePlan: ShoppingPlan
    /// Ersparnis auf den Einträgen, die in beiden Varianten enthalten sind.
    public var amount: Money
    public var comparedItemCount: Int
    /// Einträge, die die Ein-Laden-Lösung nicht abdeckt (dort nicht vergleichbar).
    public var itemsMissingInReference: Int

    public var isFullyComparable: Bool { itemsMissingInReference == 0 }
}

/// Nicht einplanbarer Eintrag inklusive Grund und Alternativvorschlägen.
public struct UnavailableItem: Identifiable, Hashable, Sendable {
    public var id: UUID { item.id }
    public var item: ShoppingListItem
    public var issues: [ItemIssue]
    public var alternatives: [StoreOption]

    public var reason: String {
        issues.first(where: \.blocksPurchase)?.message ?? "Nicht verfügbar."
    }
}

/// Hinweis zur Ergebnisanzeige.
public struct ResultNotice: Identifiable, Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case offerEndsSoon
        case outdatedPrice
        case estimatedPrice
        case preference
        case brandSubstitution
        case sampleData
        case storesExcluded
        case limitedAvailability
    }

    public var id: String { kind.rawValue + "|" + message }
    public var kind: Kind
    public var message: String
}

/// Gesamtergebnis der Optimierung.
public struct OptimizationResult: Hashable, Sendable {
    public var settings: OptimizationSettings
    public var calculatedAt: Date
    /// Empfehlung (`nil`, wenn kein einziger Eintrag einplanbar ist).
    public var recommendation: ShoppingPlan?
    public var alternatives: [PlanAlternative]
    public var unavailableItems: [UnavailableItem]
    public var savings: SavingsSummary?
    public var notices: [ResultNotice]
    /// Anzahl abgehakter Einträge, die nicht berücksichtigt wurden.
    public var skippedCheckedItemCount: Int
    /// Anzahl berücksichtigter Läden.
    public var consideredStoreCount: Int
    public var analyses: [ItemAnalysis]
}
