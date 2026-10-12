import Foundation

/// Ein Eintrag der Einkaufsliste. Kann allgemein („Laktosefreie Milch“) oder
/// markenspezifisch („Laktosefreie Milch von MinusL“) sein.
public struct ShoppingListItem: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    /// Gesuchter Produktbegriff, z. B. „Laktosefreie Milch“.
    public var query: String
    /// Anzahl Packungen (bzw. Vielfaches der gewünschten Packungsgröße).
    public var quantity: Int
    /// Gewünschte Packungsgröße. Ist sie gesetzt, wird der Bedarf als
    /// `quantity × desiredPackageSize` interpretiert und mit beliebigen Packungsgrößen gedeckt.
    public var desiredPackageSize: Quantity?
    /// Verbindliche Marke. Markenvorgaben haben Vorrang vor dem günstigsten Preis.
    public var requiredBrandID: String?
    /// Wenn die Wunschmarke nirgends verfügbar ist: Alternative automatisch einplanen?
    public var allowsBrandSubstitution: Bool
    public var prefersOrganic: Bool
    public var prefersPrivateLabel: Bool
    public var excludedBrandIDs: [String]
    public var excludedIngredients: [String]
    public var note: String
    public var isChecked: Bool

    public init(
        id: UUID = UUID(),
        query: String,
        quantity: Int = 1,
        desiredPackageSize: Quantity? = nil,
        requiredBrandID: String? = nil,
        allowsBrandSubstitution: Bool = false,
        prefersOrganic: Bool = false,
        prefersPrivateLabel: Bool = false,
        excludedBrandIDs: [String] = [],
        excludedIngredients: [String] = [],
        note: String = "",
        isChecked: Bool = false
    ) {
        self.id = id
        self.query = query
        self.quantity = max(1, quantity)
        self.desiredPackageSize = desiredPackageSize
        self.requiredBrandID = requiredBrandID
        self.allowsBrandSubstitution = allowsBrandSubstitution
        self.prefersOrganic = prefersOrganic
        self.prefersPrivateLabel = prefersPrivateLabel
        self.excludedBrandIDs = excludedBrandIDs
        self.excludedIngredients = excludedIngredients
        self.note = note
        self.isChecked = isChecked
    }

    /// Kurzbeschreibung für die Anzeige, z. B. „2 × Laktosefreie Milch (1 l)“.
    public var title: String {
        var text = quantity > 1 ? "\(quantity) × \(query)" : query
        if let size = desiredPackageSize {
            text += " (\(size.formatted))"
        }
        return text
    }
}

/// Eine gespeicherte Einkaufsliste.
public struct ShoppingList: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var items: [ShoppingListItem]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        items: [ShoppingListItem] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.items = items
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Nicht abgehakte Einträge – nur diese gehen in die Optimierung ein.
    public var openItems: [ShoppingListItem] { items.filter { !$0.isChecked } }

    /// Kopie mit neuen IDs und zurückgesetzten Häkchen (zum Wiederverwenden).
    public func duplicated(name: String? = nil, now: Date = Date()) -> ShoppingList {
        ShoppingList(
            name: name ?? "\(self.name) (Kopie)",
            items: items.map { item in
                var copy = item
                copy.id = UUID()
                copy.isChecked = false
                return copy
            },
            createdAt: now,
            updatedAt: now
        )
    }
}
