import Foundation
import Observation
import SparListeCore

/// Startet die Optimierung für eine Liste und hält das Ergebnis.
@MainActor
@Observable
public final class OptimizationViewModel {
    public enum State: Equatable {
        case idle
        case calculating
        case result(OptimizationResult)
        case failed(String)
    }

    public let listID: UUID
    public private(set) var state: State = .idle
    public private(set) var checkedItemIDs: Set<UUID> = []
    public private(set) var listName = ""
    public private(set) var priceSourceName = ""
    public var actionError: String?

    private let dependencies: AppDependencies

    public init(listID: UUID, dependencies: AppDependencies) {
        self.listID = listID
        self.dependencies = dependencies
    }

    public var result: OptimizationResult? {
        if case let .result(result) = state { return result }
        return nil
    }

    /// Lädt alle Daten über die Repositories und berechnet die Empfehlung.
    public func calculate() async {
        state = .calculating
        do {
            guard let list = try await dependencies.lists.list(id: listID) else {
                state = .failed("Die Liste wurde nicht gefunden.")
                return
            }
            let stores = try await dependencies.stores.allStores()
            let catalog = try await dependencies.catalog.catalog()
            let settings = try await dependencies.settings.settings()
            let includedIDs = Set(stores.filter(\.isIncluded).map(\.id))
            let prices = try await dependencies.prices.priceEntries(forStoreIDs: includedIDs)
            listName = list.name
            priceSourceName = dependencies.prices.descriptor.name
            checkedItemIDs = Set(list.items.filter(\.isChecked).map(\.id))

            guard !list.openItems.isEmpty else {
                state = .failed(list.items.isEmpty
                    ? "Die Liste ist leer. Füge zuerst Produkte hinzu."
                    : "Alle Produkte sind bereits abgehakt.")
                return
            }
            guard !includedIDs.isEmpty else {
                state = .failed("Es ist kein Laden für die Berechnung aktiviert. Aktiviere mindestens einen Laden unter „Läden“.")
                return
            }

            let optimizer = dependencies.optimizer
            let now = dependencies.now()
            let result = optimizer.optimize(items: list.items, stores: stores, catalog: catalog, prices: prices, settings: settings, at: now)
            state = .result(result)
        } catch {
            state = .failed(error.userMessage)
        }
    }

    public func isChecked(_ itemID: UUID) -> Bool {
        checkedItemIDs.contains(itemID)
    }

    /// Abhaken im Ergebnis: wird sofort in der Liste gespeichert. Die Empfehlung bleibt
    /// bestehen, damit die Einkaufsroute beim Abhaken nicht umspringt.
    public func toggleChecked(_ itemID: UUID) async {
        do {
            guard var list = try await dependencies.lists.list(id: listID),
                  let index = list.items.firstIndex(where: { $0.id == itemID }) else { return }
            list.items[index].isChecked.toggle()
            list.updatedAt = dependencies.now()
            try await dependencies.lists.save(list)
            if list.items[index].isChecked {
                checkedItemIDs.insert(itemID)
            } else {
                checkedItemIDs.remove(itemID)
            }
        } catch {
            actionError = error.userMessage
        }
    }

    /// Anteil der abgehakten Positionen eines Ladens (für die Fortschrittsanzeige).
    public func progress(for stop: PlanStop) -> (done: Int, total: Int) {
        (stop.lines.filter { checkedItemIDs.contains($0.item.id) }.count, stop.lines.count)
    }
}
