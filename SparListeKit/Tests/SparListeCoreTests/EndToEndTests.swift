import XCTest
@testable import SparListeCore

/// End-to-End-ähnlicher Test über die komplette Kette
/// Persistenz → Repositories → Optimierung.
///
/// Szenario: 5 Produkte, 3 aktive Läden, unterschiedliche Preise, ein aktuelles Angebot
/// (Kaffee bei REWE), ein abgelaufenes Angebot (Kaffee bei Aldi), max. 2 Läden.
///
/// Kosten je Position (Menge berücksichtigt):
///
///                    REWE    Aldi    Lidl
/// Milch 2 × 1 l      2,38    1,98    2,10
/// Butter 250 g       2,29    2,09    1,99
/// Nudeln 3 × 500 g   2,97    2,67    2,85
/// Kaffee 500 g       3,99*   5,49    4,99     (* Angebot statt 6,99; Aldi-Angebot 2,99 abgelaufen)
/// Eier 10 Stk.       2,79    2,49    2,59
///
/// Paare: REWE+Aldi 13,22 · REWE+Lidl 13,52 · Aldi+Lidl 14,12
/// Ein Laden: REWE 14,42 · Lidl 14,52 · Aldi 14,72
/// Erwartet: REWE (Kaffee) + Aldi (Rest) = 13,22 €, Ersparnis 1,20 € ggü. REWE allein.
final class EndToEndTests: XCTestCase {
    func testFiveProductsThreeStoresOneOfferMaxTwoStores() async throws {
        let rewe = Store(id: "rewe", chain: .rewe, name: "REWE", distanceKm: 1.0, isIncluded: true)
        let aldi = Store(id: "aldi", chain: .aldi, name: "Aldi", distanceKm: 2.0, isIncluded: true)
        let lidl = Store(id: "lidl", chain: .lidl, name: "Lidl", distanceKm: 3.0, isIncluded: true)
        let edeka = Store(id: "edeka", chain: .edeka, name: "EDEKA", distanceKm: 0.5, isIncluded: false) // deaktiviert

        let products = [
            Product(id: "milch", name: "Vollmilch 1 l", genericName: "Milch", packageSize: Quantity(1, .liter)),
            Product(id: "butter", name: "Butter 250 g", genericName: "Butter", packageSize: Quantity(250, .gram)),
            Product(id: "nudeln", name: "Penne 500 g", genericName: "Nudeln", packageSize: Quantity(500, .gram)),
            Product(id: "kaffee", name: "Kaffee 500 g", genericName: "Kaffee", packageSize: Quantity(500, .gram)),
            Product(id: "eier", name: "Eier 10 Stk.", genericName: "Eier", packageSize: Quantity(10, .piece))
        ]
        let table: [(String, [String: Double])] = [
            ("milch", ["rewe": 1.19, "aldi": 0.99, "lidl": 1.05, "edeka": 0.50]),
            ("butter", ["rewe": 2.29, "aldi": 2.09, "lidl": 1.99, "edeka": 0.50]),
            ("nudeln", ["rewe": 0.99, "aldi": 0.89, "lidl": 0.95, "edeka": 0.50]),
            ("kaffee", ["rewe": 6.99, "aldi": 5.49, "lidl": 4.99, "edeka": 0.50]),
            ("eier", ["rewe": 2.79, "aldi": 2.49, "lidl": 2.59, "edeka": 0.50])
        ]
        var prices = table.flatMap { productID, byStore in
            byStore.map { TestSupport.price(productID, $0.key, $0.value) }
        }
        prices.append(TestSupport.offer("kaffee", "rewe", 3.99, from: -2, until: 4))   // aktuell gültig
        prices.append(TestSupport.offer("kaffee", "aldi", 2.99, from: -14, until: -7)) // abgelaufen

        let list = ShoppingList(name: "E2E", items: [
            ShoppingListItem(query: "Milch", quantity: 2, desiredPackageSize: Quantity(1, .liter)),
            ShoppingListItem(query: "Butter"),
            ShoppingListItem(query: "Nudeln", quantity: 3),
            ShoppingListItem(query: "Kaffee"),
            ShoppingListItem(query: "Eier")
        ])
        let settings = OptimizationSettings(mode: .cheapestWithStoreLimit, storeLimit: .two)

        // Über die echte lokale Datenquelle (JSON-Datei) laden.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sparliste-e2e-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let seed = AppData(lists: [list], stores: [rewe, aldi, lidl, edeka], products: products, prices: prices, settings: settings)
        _ = try LocalDataStore(persistence: JSONFilePersistence(fileURL: url), seed: { seed })
        let store = try LocalDataStore(persistence: JSONFilePersistence(fileURL: url)) // neu von Platte lesen

        let storedList = await store.list(id: list.id)
        let loadedList = try XCTUnwrap(storedList)
        let loadedStores = await store.allStores()
        let included = Set(loadedStores.filter(\.isIncluded).map(\.id))
        let catalog = await store.catalog()
        let loadedPrices = await store.priceEntries(forStoreIDs: included)
        let loadedSettings = await store.settings()
        let result = TestSupport.optimizer.optimize(
            items: loadedList.items,
            stores: loadedStores,
            catalog: catalog,
            prices: loadedPrices,
            settings: loadedSettings,
            at: TestSupport.now
        )

        let plan = try XCTUnwrap(result.recommendation)
        XCTAssertEqual(plan.storeCount, 2)
        XCTAssertEqual(Set(plan.storeIDs), ["rewe", "aldi"])
        XCTAssertEqual(plan.storeIDs, ["rewe", "aldi"], "Reihenfolge nach Entfernung")
        XCTAssertEqual(plan.assignment, ["Milch": "aldi", "Butter": "aldi", "Nudeln": "aldi", "Kaffee": "rewe", "Eier": "aldi"])
        XCTAssertEqual(plan.total, Money(euros: 13.22))

        let reweStop = try XCTUnwrap(plan.stops.first { $0.store.id == "rewe" })
        XCTAssertEqual(reweStop.subtotal, Money(euros: 3.99))
        let coffee = try XCTUnwrap(reweStop.lines.first)
        XCTAssertTrue(coffee.option.isOffer)
        XCTAssertEqual(coffee.option.regularPrice, Money(euros: 6.99))

        let aldiStop = try XCTUnwrap(plan.stops.first { $0.store.id == "aldi" })
        XCTAssertEqual(aldiStop.subtotal, Money(euros: 9.23))
        let milk = try XCTUnwrap(aldiStop.lines.first { $0.item.query == "Milch" })
        XCTAssertEqual(milk.option.packageCount, 2)
        XCTAssertEqual(milk.option.unitPrice?.formatted, "0,99 € / 1 l")
        let pasta = try XCTUnwrap(aldiStop.lines.first { $0.item.query == "Nudeln" })
        XCTAssertEqual(pasta.option.packageCount, 3)
        XCTAssertEqual(pasta.lineTotal, Money(euros: 2.67))

        XCTAssertEqual(result.savings?.referencePlan.storeIDs, ["rewe"])
        XCTAssertEqual(result.savings?.referencePlan.total, Money(euros: 14.42))
        XCTAssertEqual(result.savings?.amount, Money(euros: 1.20))
        XCTAssertTrue(result.unavailableItems.isEmpty)
        XCTAssertEqual(result.consideredStoreCount, 3)
    }
}
