import XCTest
@testable import SparListeCore

final class OfferValidityTests: XCTestCase {
    private let validity = OfferValidity(calendar: TestSupport.calendar)

    func testRegularPriceIsAlwaysValid() {
        XCTAssertTrue(validity.isValid(TestSupport.price("x", "s", 1), at: TestSupport.now))
    }

    func testOfferIsValidWithinPeriodIncludingWholeLastDay() {
        let offer = TestSupport.offer("x", "s", 1, from: -2, until: 0)
        XCTAssertTrue(validity.isValid(offer, at: TestSupport.now))
        // Letzter Gültigkeitstag 23:59 → noch gültig.
        XCTAssertTrue(validity.isValid(offer, at: TestSupport.date(2026, 10, 12, hour: 23, minute: 59)))
        // Folgetag 00:00 → abgelaufen.
        XCTAssertFalse(validity.isValid(offer, at: TestSupport.date(2026, 10, 13, hour: 0, minute: 0)))
    }

    func testOfferIsValidFromStartOfFirstDay() {
        let offer = TestSupport.offer("x", "s", 1, from: 1, until: 3)
        XCTAssertFalse(validity.isValid(offer, at: TestSupport.now))
        XCTAssertTrue(validity.isValid(offer, at: TestSupport.date(2026, 10, 13, hour: 0, minute: 0)))
    }

    func testExpiredOfferIsInvalid() {
        XCTAssertFalse(validity.isValid(TestSupport.offer("x", "s", 1, from: -10, until: -1), at: TestSupport.now))
    }

    func testEndsSoonAndDaysRemaining() {
        let soon = TestSupport.offer("x", "s", 1, from: -1, until: 1)
        let later = TestSupport.offer("x", "s", 1, from: -1, until: 6)
        XCTAssertEqual(validity.daysRemaining(soon, at: TestSupport.now), 1)
        XCTAssertTrue(validity.endsSoon(soon, at: TestSupport.now, withinDays: 2))
        XCTAssertFalse(validity.endsSoon(later, at: TestSupport.now, withinDays: 2))
    }

    func testResolverIgnoresExpiredAndFutureOffers() {
        let entries = [
            TestSupport.price("x", "s", 2.00),
            TestSupport.offer("x", "s", 1.00, from: -9, until: -2),
            TestSupport.offer("x", "s", 0.90, from: 2, until: 5)
        ]
        let resolved = TestSupport.resolver.resolve(entries, at: TestSupport.now)
        XCTAssertEqual(resolved?.price, Money(euros: 2.00))
        XCTAssertEqual(resolved?.isOffer, false)
    }

    func testResolverPrefersValidOfferAndKeepsRegularPrice() {
        let entries = [TestSupport.price("x", "s", 2.00), TestSupport.offer("x", "s", 1.49, from: -1, until: 3)]
        let resolved = TestSupport.resolver.resolve(entries, at: TestSupport.now)
        XCTAssertEqual(resolved?.price, Money(euros: 1.49))
        XCTAssertEqual(resolved?.isOffer, true)
        XCTAssertEqual(resolved?.regularPrice, Money(euros: 2.00))
    }

    func testResolverRespectsAvailability() {
        let unavailable = [TestSupport.price("x", "s", 1.00, availability: .unavailable)]
        XCTAssertNil(TestSupport.resolver.resolve(unavailable, at: TestSupport.now))

        // Neuere Meldung „nicht verfügbar“ schlägt älteren verfügbaren Preis.
        let newerUnavailable = [
            TestSupport.price("x", "s", 1.00, observedDaysAgo: 5),
            TestSupport.price("x", "s", 1.10, availability: .unavailable, observedDaysAgo: 1)
        ]
        XCTAssertNil(TestSupport.resolver.resolve(newerUnavailable, at: TestSupport.now))
    }

    func testFreshnessCurrentEstimatedOutdated() {
        let policy = PriceFreshnessPolicy(maxAgeDays: 14)
        XCTAssertEqual(policy.freshness(of: TestSupport.price("x", "s", 1, observedDaysAgo: 3), at: TestSupport.now), .current)
        XCTAssertEqual(policy.freshness(of: TestSupport.price("x", "s", 1, observedDaysAgo: 30), at: TestSupport.now), .outdated)
        XCTAssertEqual(policy.freshness(of: TestSupport.price("x", "s", 1, source: .estimate), at: TestSupport.now), .estimated)
        XCTAssertEqual(policy.freshness(of: TestSupport.offer("x", "s", 1, from: -20, until: 2), at: TestSupport.now), .current)
    }

    func testOutdatedAndEstimatedPricesAreFlaggedInResult() {
        let products = [TestSupport.product("a", generic: "Mehl"), TestSupport.product("b", generic: "Zucker")]
        let prices = [
            TestSupport.price("a", "s1", 0.79, observedDaysAgo: 40),
            TestSupport.price("b", "s1", 0.99, source: .estimate)
        ]
        let result = TestSupport.optimize([ShoppingListItem(query: "Mehl"), ShoppingListItem(query: "Zucker")],
                                          stores: [TestSupport.store("s1")], products: products, prices: prices,
                                          settings: TestSupport.settings(.cheapestOverall))
        let kinds = Set(result.notices.map(\.kind))
        XCTAssertTrue(kinds.contains(.outdatedPrice))
        XCTAssertTrue(kinds.contains(.estimatedPrice))
        let freshness = Dictionary(uniqueKeysWithValues: result.recommendation!.lines.map { ($0.item.query, $0.option.freshness) })
        XCTAssertEqual(freshness["Mehl"], .outdated)
        XCTAssertEqual(freshness["Zucker"], .estimated)
    }

    func testOfferEndingSoonProducesNotice() {
        let products = [TestSupport.product("a", generic: "Kaffee")]
        let prices = [TestSupport.price("a", "s1", 6.99), TestSupport.offer("a", "s1", 4.99, from: -3, until: 1)]
        let result = TestSupport.optimize([ShoppingListItem(query: "Kaffee")], stores: [TestSupport.store("s1")],
                                          products: products, prices: prices, settings: TestSupport.settings(.cheapestOverall))
        XCTAssertEqual(result.recommendation?.lines.first?.option.offerEndsSoon, true)
        XCTAssertTrue(result.notices.contains { $0.kind == .offerEndsSoon && $0.message.contains("13.10.") })
    }
}
