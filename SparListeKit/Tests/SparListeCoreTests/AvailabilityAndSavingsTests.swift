import XCTest
@testable import SparListeCore

final class AvailabilityAndSavingsTests: XCTestCase {
    private let products = [
        TestSupport.product("milch", generic: "Milch"),
        TestSupport.product("brot", generic: "Brot"),
        TestSupport.product("safran", generic: "Safran")
    ]
    private let stores = [TestSupport.store("A", distance: 1), TestSupport.store("B", distance: 2)]

    func testProductWithoutAnyPriceInIncludedStoresIsUnavailable() {
        let prices = [
            TestSupport.price("milch", "A", 1.00),
            TestSupport.price("brot", "B", 2.00),
            TestSupport.price("safran", "X", 4.00) // nur in einem nicht berücksichtigten Laden
        ]
        let items = [ShoppingListItem(query: "Milch"), ShoppingListItem(query: "Brot"), ShoppingListItem(query: "Safran")]
        let result = TestSupport.optimize(items, stores: stores, products: products, prices: prices,
                                          settings: TestSupport.settings(.cheapestOverall))
        XCTAssertEqual(result.unavailableItems.map(\.item.query), ["Safran"])
        XCTAssertEqual(result.unavailableItems.first?.issues, [.notAvailableInIncludedStores])
        XCTAssertEqual(result.recommendation?.coveredItemCount, 2)
        XCTAssertEqual(result.recommendation?.total, Money(euros: 3.00))
    }

    func testUnknownProductIsUnavailable() {
        let result = TestSupport.optimize([ShoppingListItem(query: "Drachenfrucht")], stores: stores, products: products,
                                          prices: [TestSupport.price("milch", "A", 1)], settings: TestSupport.settings(.cheapestOverall))
        XCTAssertNil(result.recommendation)
        XCTAssertEqual(result.unavailableItems.first?.issues, [.noMatchingProduct])
    }

    func testUnavailableStatusExcludesStore() {
        let prices = [
            TestSupport.price("milch", "A", 0.50, availability: .unavailable),
            TestSupport.price("milch", "B", 1.00)
        ]
        let result = TestSupport.optimize([ShoppingListItem(query: "Milch")], stores: stores, products: products, prices: prices,
                                          settings: TestSupport.settings(.cheapestOverall))
        XCTAssertEqual(result.recommendation?.storeIDs, ["B"])
    }

    func testSingleStorePlanReportsItemsItCannotCover() {
        let prices = [TestSupport.price("milch", "A", 1.00), TestSupport.price("brot", "B", 2.00)]
        let items = [ShoppingListItem(query: "Milch"), ShoppingListItem(query: "Brot")]
        let result = TestSupport.optimize(items, stores: stores, products: products, prices: prices,
                                          settings: TestSupport.settings(.singleStore))
        XCTAssertEqual(result.recommendation?.coveredItemCount, 1)
        XCTAssertEqual(result.recommendation?.uncoveredItems.count, 1)
    }

    func testSavingsAgainstBestSingleStore() {
        let prices = [
            TestSupport.price("milch", "A", 1.00), TestSupport.price("milch", "B", 0.70),
            TestSupport.price("brot", "A", 2.00), TestSupport.price("brot", "B", 2.60)
        ]
        let items = [ShoppingListItem(query: "Milch"), ShoppingListItem(query: "Brot")]
        let result = TestSupport.optimize(items, stores: stores, products: products, prices: prices,
                                          settings: TestSupport.settings(.cheapestOverall))
        // Ein Laden: A = 3,00 / B = 3,30 → A. Kombination: 0,70 + 2,00 = 2,70. Ersparnis 0,30.
        XCTAssertEqual(result.recommendation?.total, Money(euros: 2.70))
        XCTAssertEqual(result.savings?.referencePlan.storeIDs, ["A"])
        XCTAssertEqual(result.savings?.amount, Money(euros: 0.30))
        XCTAssertEqual(result.savings?.isFullyComparable, true)
    }

    func testSavingsAreZeroWhenRecommendationIsSingleStore() {
        let prices = [TestSupport.price("milch", "A", 1.00), TestSupport.price("brot", "A", 2.00)]
        let result = TestSupport.optimize([ShoppingListItem(query: "Milch"), ShoppingListItem(query: "Brot")], stores: stores,
                                          products: products, prices: prices, settings: TestSupport.settings(.cheapestOverall))
        XCTAssertEqual(result.savings?.amount, .zero)
    }

    func testSavingsOnlyCompareItemsCoveredByBoth() {
        // Brot gibt es nur in B. Die Ein-Laden-Lösung (B, volle Abdeckung) wird mit der Empfehlung verglichen.
        let prices = [
            TestSupport.price("milch", "A", 0.50), TestSupport.price("milch", "B", 1.00),
            TestSupport.price("brot", "B", 2.00)
        ]
        let items = [ShoppingListItem(query: "Milch"), ShoppingListItem(query: "Brot")]
        let result = TestSupport.optimize(items, stores: stores, products: products, prices: prices,
                                          settings: TestSupport.settings(.cheapestOverall))
        XCTAssertEqual(result.savings?.referencePlan.storeIDs, ["B"])
        XCTAssertEqual(result.savings?.amount, Money(euros: 0.50))

        // Direkter Vergleich mit einer Referenz, die ein Produkt nicht abdeckt.
        let plan = result.recommendation!
        let partialReference = ShoppingPlan(
            stops: [PlanStop(store: stores[0], lines: plan.lines.filter { $0.item.query == "Milch" })],
            route: Route(orderedStores: [stores[0]], distanceKm: 2, basis: .homeDistances),
            uncoveredItems: []
        )
        let summary = ShoppingOptimizer.savings(of: plan, comparedTo: partialReference)
        XCTAssertEqual(summary.comparedItemCount, 1)
        XCTAssertEqual(summary.itemsMissingInReference, 1)
        XCTAssertFalse(summary.isFullyComparable)
    }
}
