import XCTest
@testable import SparListeCore

/// Prüft die im README dokumentierte Beispielrechnung („Wocheneinkauf“ mit den Beispieldaten).
final class SampleScenarioTests: XCTestCase {
    private func result(_ mode: OptimizationMode, limit: StoreLimit = .two) -> OptimizationResult {
        let data = SampleData.make(now: TestSupport.now, calendar: TestSupport.calendar)
        var settings = data.settings
        settings.mode = mode
        settings.storeLimit = limit
        return TestSupport.optimizer.optimize(items: SampleData.weeklyList(now: TestSupport.now).items, stores: data.stores,
                                              catalog: data.catalog, prices: data.prices, settings: settings, at: TestSupport.now)
    }

    func testSampleDataMeetsMinimumSize() {
        let data = SampleData.make(now: TestSupport.now)
        XCTAssertGreaterThanOrEqual(data.stores.count, 3)
        XCTAssertGreaterThanOrEqual(Set(data.products.map(\.genericName)).count, 10)
        XCTAssertGreaterThanOrEqual(data.brands.count, 5)
        let validity = OfferValidity(calendar: TestSupport.calendar)
        XCTAssertGreaterThanOrEqual(data.prices.filter { $0.isOffer && validity.isValid($0, at: TestSupport.now) }.count, 3)
        XCTAssertTrue(data.prices.allSatisfy { $0.source == .sampleData || $0.source == .estimate })
    }

    func testWeeklyListWithMaxTwoStores() throws {
        let result = result(.cheapestWithStoreLimit)
        let plan = try XCTUnwrap(result.recommendation)
        XCTAssertEqual(plan.storeIDs, [SampleData.StoreID.rewe, SampleData.StoreID.lidl])
        XCTAssertEqual(plan.stops[0].subtotal, Money(euros: 5.67))
        XCTAssertEqual(plan.stops[1].subtotal, Money(euros: 12.20))
        XCTAssertEqual(plan.total, Money(euros: 17.87))
        XCTAssertEqual(plan.assignment, [
            "Laktosefreie Milch": SampleData.StoreID.rewe,
            "Bananen": SampleData.StoreID.rewe,
            "Butter": SampleData.StoreID.lidl,
            "Spaghetti": SampleData.StoreID.lidl,
            "Kaffee": SampleData.StoreID.lidl,
            "Haferflocken": SampleData.StoreID.lidl,
            "Eier": SampleData.StoreID.lidl
        ])
        XCTAssertEqual(result.savings?.referencePlan.storeIDs, [SampleData.StoreID.rewe])
        XCTAssertEqual(result.savings?.referencePlan.total, Money(euros: 19.91))
        XCTAssertEqual(result.savings?.amount, Money(euros: 2.04))
        XCTAssertEqual(result.unavailableItems.map(\.item.query), ["Hafermilch Barista"])
        XCTAssertTrue(result.notices.contains { $0.kind == .offerEndsSoon && $0.message.contains("Barilla") })
        XCTAssertTrue(result.notices.contains { $0.kind == .sampleData })
    }

    func testWeeklyListOtherModes() {
        XCTAssertEqual(result(.singleStore).recommendation?.total, Money(euros: 19.91))
        let overall = result(.cheapestOverall).recommendation
        XCTAssertEqual(overall?.total, Money(euros: 16.77))
        XCTAssertEqual(Set(overall?.storeIDs ?? []), [SampleData.StoreID.aldi, SampleData.StoreID.lidl, SampleData.StoreID.edeka])
        XCTAssertEqual(result(.cheapestWithStoreLimit, limit: .three).recommendation?.total, Money(euros: 16.77))
        // Kompromiss (0,30 €/km): REWE allein ist am nächsten und gewinnt.
        XCTAssertEqual(result(.balanced).recommendation?.storeIDs, [SampleData.StoreID.rewe])
    }

    func testExpiredOfferIsNotUsed() {
        // Ja! Butter hat ein abgelaufenes Angebot (1,79 €); in der REWE-Lösung muss 2,19 € stehen.
        let plan = result(.singleStore).recommendation
        let butter = plan?.lines.first { $0.item.query == "Butter" }
        XCTAssertEqual(butter?.option.product.id, "butter-ja")
        XCTAssertEqual(butter?.lineTotal, Money(euros: 2.19))
        XCTAssertEqual(butter?.option.isOffer, false)
    }
}
