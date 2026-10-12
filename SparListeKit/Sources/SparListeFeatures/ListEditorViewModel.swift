import Foundation
import Observation
import SparListeCore

/// Einkaufsliste bearbeiten: Einträge hinzufügen, ändern, löschen, abhaken.
@MainActor
@Observable
public final class ListEditorViewModel {
    public let listID: UUID
    public private(set) var list: ShoppingList?
    public private(set) var catalog = Catalog()
    public private(set) var state: LoadState = .idle
    public var actionError: String?

    private let dependencies: AppDependencies

    public init(listID: UUID, dependencies: AppDependencies) {
        self.listID = listID
        self.dependencies = dependencies
    }

    public var openItems: [ShoppingListItem] { list?.items.filter { !$0.isChecked } ?? [] }
    public var checkedItems: [ShoppingListItem] { list?.items.filter(\.isChecked) ?? [] }

    public func load() async {
        if list == nil { state = .loading }
        do {
            catalog = try await dependencies.catalog.catalog()
            guard let loaded = try await dependencies.lists.list(id: listID) else {
                state = .failed("Die Liste wurde nicht gefunden.")
                return
            }
            list = loaded
            state = .loaded
        } catch {
            state = .failed(error.userMessage)
        }
    }

    // MARK: Autovervollständigung & Marken

    public func suggestions(for text: String) -> [ProductSuggestion] {
        ProductSuggestionService(catalog: catalog).suggestions(for: text)
    }

    public func brands(for query: String) -> [Brand] {
        let found = ProductSuggestionService(catalog: catalog).brands(forGenericName: query)
        return found.isEmpty ? catalog.brands.sorted { $0.name < $1.name } : found
    }

    public func brandName(for id: String?) -> String? {
        catalog.brand(id: id)?.name
    }

    /// Neuer Eintrag aus einem Vorschlag (übernimmt Marke und typische Packungsgröße).
    public func makeItem(from suggestion: ProductSuggestion, quantity: Int = 1) -> ShoppingListItem {
        ShoppingListItem(
            query: suggestion.genericName,
            quantity: quantity,
            desiredPackageSize: suggestion.typicalPackageSize,
            requiredBrandID: suggestion.brandID
        )
    }

    // MARK: Bearbeiten

    public func add(_ item: ShoppingListItem) async {
        guard !item.query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        await mutate { $0.items.append(item) }
    }

    public func update(_ item: ShoppingListItem) async {
        await mutate { list in
            if let index = list.items.firstIndex(where: { $0.id == item.id }) {
                list.items[index] = item
            }
        }
    }

    public func delete(_ item: ShoppingListItem) async {
        await mutate { $0.items.removeAll { $0.id == item.id } }
    }

    public func toggleChecked(_ item: ShoppingListItem) async {
        await mutate { list in
            if let index = list.items.firstIndex(where: { $0.id == item.id }) {
                list.items[index].isChecked.toggle()
            }
        }
    }

    public func uncheckAll() async {
        await mutate { list in
            for index in list.items.indices { list.items[index].isChecked = false }
        }
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) async {
        await mutate { list in
            let moving = source.sorted().map { list.items[$0] }
            for index in source.sorted(by: >) { list.items.remove(at: index) }
            let shift = source.filter { $0 < destination }.count
            list.items.insert(contentsOf: moving, at: min(destination - shift, list.items.count))
        }
    }

    public func rename(to name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await mutate { $0.name = trimmed }
    }

    private func mutate(_ change: (inout ShoppingList) -> Void) async {
        guard var updated = list else { return }
        change(&updated)
        updated.updatedAt = dependencies.now()
        let previous = list
        list = updated // sofortige UI-Aktualisierung
        do {
            try await dependencies.lists.save(updated)
        } catch {
            list = previous
            actionError = error.userMessage
        }
    }
}
