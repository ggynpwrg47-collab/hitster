import XCTest
import SparListeCore
@testable import SparListeFeatures

@MainActor
final class ViewModelTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func dependencies() throws -> (AppDependencies, LocalDataStore) {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 10))!
        let cal = calendar
        let store = try LocalDataStore(persistence: InMemoryPersistence(), seed: { SampleData.make(now: now, calendar: cal) })
        var deps = AppDependencies.local(store, now: { now })
        deps.optimizer = ShoppingOptimizer(resolver: PriceResolver(validity: OfferValidity(calendar: cal)))
        return (deps, store)
    }

    func testOverviewLoadsCreatesDuplicatesAndDeletes() async throws {
        let (deps, _) = try dependencies()
        let viewModel = ListsOverviewViewModel(dependencies: deps)
        await viewModel.load()
        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(viewModel.lists.count, 2)

        let createdList = await viewModel.createList(named: "  Grillen  ")
        let created = try XCTUnwrap(createdList)
        XCTAssertEqual(created.name, "Grillen")
        XCTAssertEqual(viewModel.lists.count, 3)

        let weekly = try XCTUnwrap(viewModel.lists.first { $0.name == "Wocheneinkauf" })
        let duplicated = await viewModel.duplicate(weekly)
        let copy = try XCTUnwrap(duplicated)
        XCTAssertEqual(copy.items.count, weekly.items.count)
        XCTAssertEqual(viewModel.lists.count, 4)

        await viewModel.delete(created)
        XCTAssertFalse(viewModel.lists.contains { $0.id == created.id })
    }

    func testEditorAddsChecksAndSuggests() async throws {
        let (deps, _) = try dependencies()
        let editor = ListEditorViewModel(listID: SampleData.weeklyList().id, dependencies: deps)
        await editor.load()
        XCTAssertEqual(editor.state, .loaded)
        let before = editor.list?.items.count ?? 0

        let suggestion = try XCTUnwrap(editor.suggestions(for: "Spag").first)
        let item = editor.makeItem(from: suggestion, quantity: 3)
        XCTAssertEqual(item.desiredPackageSize, Quantity(500, .gram))
        await editor.add(item)
        XCTAssertEqual(editor.list?.items.count, before + 1)

        await editor.toggleChecked(item)
        XCTAssertTrue(editor.checkedItems.contains { $0.id == item.id })

        // Neu laden → Änderungen sind persistiert.
        let reloaded = ListEditorViewModel(listID: SampleData.weeklyList().id, dependencies: deps)
        await reloaded.load()
        XCTAssertEqual(reloaded.list?.items.last?.isChecked, true)

        await reloaded.delete(item)
        XCTAssertEqual(reloaded.list?.items.count, before)
    }

    func testOptimizationViewModelCalculatesAndChecksItems() async throws {
        let (deps, store) = try dependencies()
        let viewModel = OptimizationViewModel(listID: SampleData.weeklyList().id, dependencies: deps)
        await viewModel.calculate()
        let result = try XCTUnwrap(viewModel.result)
        XCTAssertEqual(result.recommendation?.total, Money(euros: 17.87))

        let line = try XCTUnwrap(result.recommendation?.lines.first)
        await viewModel.toggleChecked(line.item.id)
        XCTAssertTrue(viewModel.isChecked(line.item.id))
        let saved = await store.list(id: SampleData.weeklyList().id)
        XCTAssertEqual(saved?.items.first { $0.id == line.item.id }?.isChecked, true)

        // Neu berechnen: abgehaktes Produkt fällt aus der Optimierung.
        await viewModel.calculate()
        XCTAssertEqual(viewModel.result?.skippedCheckedItemCount, 1)
        XCTAssertNil(viewModel.result?.recommendation?.lines.first { $0.item.id == line.item.id })
    }

    func testOptimizationViewModelErrorStates() async throws {
        let (deps, store) = try dependencies()
        let empty = ShoppingList(name: "Leer")
        try await store.save(empty)
        let viewModel = OptimizationViewModel(listID: empty.id, dependencies: deps)
        await viewModel.calculate()
        XCTAssertEqual(viewModel.state, .failed("Die Liste ist leer. Füge zuerst Produkte hinzu."))

        for var shop in await store.allStores() {
            shop.isIncluded = false
            try await store.save(shop)
        }
        let noStores = OptimizationViewModel(listID: SampleData.weeklyList().id, dependencies: deps)
        await noStores.calculate()
        if case let .failed(message) = noStores.state {
            XCTAssertTrue(message.contains("kein Laden"))
        } else {
            XCTFail("Fehlerzustand erwartet")
        }
    }

    func testStoresViewModelTogglesAndSettings() async throws {
        let (deps, _) = try dependencies()
        let viewModel = StoresViewModel(dependencies: deps)
        await viewModel.load()
        XCTAssertEqual(viewModel.includedCount, 4)
        let lidl = try XCTUnwrap(viewModel.stores.first { $0.chain == .lidl })
        await viewModel.setIncluded(lidl, false)
        XCTAssertEqual(viewModel.includedCount, 3)

        await viewModel.setStoreLimit(.three)
        await viewModel.setMode(.balanced)
        let reloaded = StoresViewModel(dependencies: deps)
        await reloaded.load()
        XCTAssertEqual(reloaded.settings.storeLimit, .three)
        XCTAssertEqual(reloaded.settings.mode, .balanced)
        XCTAssertEqual(reloaded.isOpenNow(lidl), true) // Montag 10 Uhr

        let newStore = viewModel.newStoreTemplate(chain: .penny)
        XCTAssertEqual(newStore.name, "Penny")
        await viewModel.save(newStore)
        XCTAssertEqual(viewModel.stores.count, 5)

        await viewModel.resetSampleData()
        XCTAssertEqual(viewModel.stores.count, 4)
        XCTAssertEqual(viewModel.includedCount, 4)
    }

    func testCatalogViewModelAddsPrice() async throws {
        let (deps, _) = try dependencies()
        let viewModel = CatalogViewModel(dependencies: deps)
        await viewModel.load()
        let product = try XCTUnwrap(viewModel.catalog.products.first { $0.id == "butter-ja" })
        var entry = viewModel.newPriceTemplate(for: product)
        entry.price = Money(euros: 1.89)
        await viewModel.save(entry)
        XCTAssertTrue(viewModel.prices(for: product).contains { $0.id == entry.id && $0.source == .manualEntry })
        viewModel.searchText = "kerrygold"
        XCTAssertEqual(viewModel.groupedProducts.map(\.genericName), ["Butter"])
    }
}
