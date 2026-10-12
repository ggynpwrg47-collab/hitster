import Foundation
import Observation
import SparListeCore

/// Startbildschirm: gespeicherte Einkaufslisten.
@MainActor
@Observable
public final class ListsOverviewViewModel {
    public private(set) var lists: [ShoppingList] = []
    public private(set) var state: LoadState = .idle
    public var actionError: String?

    private let dependencies: AppDependencies

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    public var isEmpty: Bool { state == .loaded && lists.isEmpty }

    public func load() async {
        if lists.isEmpty { state = .loading }
        do {
            lists = try await dependencies.lists.allLists()
            state = .loaded
        } catch {
            state = .failed(error.userMessage)
        }
    }

    @discardableResult
    public func createList(named name: String) async -> ShoppingList? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = dependencies.now()
        let list = ShoppingList(name: trimmed.isEmpty ? "Neue Liste" : trimmed, createdAt: now, updatedAt: now)
        return await perform { try await self.dependencies.lists.save(list) } ? list : nil
    }

    @discardableResult
    public func duplicate(_ list: ShoppingList) async -> ShoppingList? {
        let copy = list.duplicated(now: dependencies.now())
        return await perform { try await self.dependencies.lists.save(copy) } ? copy : nil
    }

    public func delete(_ list: ShoppingList) async {
        await perform { try await self.dependencies.lists.deleteList(id: list.id) }
    }

    public func rename(_ list: ShoppingList, to name: String) async {
        var updated = list
        updated.name = name
        updated.updatedAt = dependencies.now()
        await perform { try await self.dependencies.lists.save(updated) }
    }

    @discardableResult
    private func perform(_ action: @escaping () async throws -> Void) async -> Bool {
        do {
            try await action()
            await load()
            return true
        } catch {
            actionError = error.userMessage
            return false
        }
    }

    /// Kurzinfo für die Listenzeile, z. B. „3 von 8 erledigt“.
    public static func progressText(for list: ShoppingList) -> String {
        guard !list.items.isEmpty else { return "Keine Produkte" }
        let checked = list.items.filter(\.isChecked).count
        return checked == 0 ? "\(list.items.count) Produkte" : "\(checked) von \(list.items.count) erledigt"
    }
}
