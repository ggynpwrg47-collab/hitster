import XCTest
@testable import SparListeCore

/// Kleines Szenario mit klar unterscheidbaren Preisen.
///
///             A      B      C      D
/// Milch     1,00   0,80   1,20     –
/// Brot      2,00   2,50   1,50     –
/// Käse      3,00   3,50   3,20   2,00
/// Kaffee    5,00   4,00   6,00     –
final class OptimizerTests: XCTestCase {
    private let products = [
        TestSupport.product("milch", generic: "Milch"),
        TestSupport.product("brot", generic: "Brot"),
        TestSupport.product("kaese", generic: "Käse"),
        TestSupport.product("kaffee", generic: "Kaffee")
    ]
    private let stores = [
        TestSupport.store("A", distance: 1),
        TestSupport.store("B", distance: 2),
        TestSupport.store("C", distance: 3),
        TestSupport.store("D", distance: 8)
    ]
    private var prices: [PriceEntry] {
        [
            TestSupport.price("milch", "A", 1.00), TestSupport.price("milch", "B", 0.80), TestSupport.price("milch", "C", 1.20),
            TestSupport.price("brot", "A", 2.00), TestSupport.price("brot", "B", 2.50), TestSupport.price("brot", "C", 1.50),
            TestSupport.price("kaese", "A", 3.00), TestSupport.price("kaese", "B", 3.50), TestSupport.price("kaese", "C", 3.20),
            TestSupport.price("kaese", "D", 2.00),
            TestSupport.price("kaffee", "A", 5.00), TestSupport.price("kaffee", "B", 4.00), TestSupport.price("kaffee", "C", 6.00)
        ]
    }
    private let items = ["Milch", "Brot", "Käse", "Kaffee"].map { ShoppingListItem(query: $0) }

    private func run(_ mode: OptimizationMode, limit: StoreLimit = .unlimited, stores: [Store]? = nil, items: [ShoppingListItem]? = nil) -> OptimizationResult {
        TestSupport.optimize(items ?? self.items, stores: stores ?? self.stores, products: products, prices: prices,
                             settings: TestSupport.settings(mode, limit: limit))
    }

    // MARK: Ein Laden

    func testSingleStoreChoosesCheapestCompleteStore() {
        // A: 11,00 · B: 10,80 · C: 11,90 · D deckt nur Käse ab.
        let plan = run(.singleStore).recommendation
        XCTAssertEqual(plan?.storeIDs, ["B"])
        XCTAssertEqual(plan?.total, Money(euros: 10.80))
        XCTAssertEqual(plan?.coveredItemCount, 4)
    }

    func testSingleStorePrefersCoverageOverPrice() {
        // D ist für Käse am günstigsten, deckt aber nicht alles ab → B bleibt die Ein-Laden-Lösung.
        let plan = run(.singleStore, items: [ShoppingListItem(query: "Käse"), ShoppingListItem(query: "Milch")]).recommendation
        XCTAssertEqual(plan?.storeIDs, ["A"]) // A: 4,00 · B: 4,30 · C: 4,40
        XCTAssertEqual(plan?.total, Money(euros: 4.00))
    }

    // MARK: Mehrere Läden

    func testCheapestOverallUsesEveryStoreThatHelps() {
        // Milch B 0,80 · Brot C 1,50 · Käse D 2,00 · Kaffee B 4,00 = 8,30
        let plan = run(.cheapestOverall).recommendation
        XCTAssertEqual(plan?.total, Money(euros: 8.30))
        XCTAssertEqual(Set(plan?.storeIDs ?? []), ["B", "C", "D"])
        XCTAssertEqual(plan?.assignment, ["Milch": "B", "Brot": "C", "Käse": "D", "Kaffee": "B"])
    }

    func testMaxTwoStores() {
        // Beste Paare: B+D = 0,80+2,50+2,00+4,00 = 9,30 · B+C = 0,80+1,50+3,20+4,00 = 9,50 · A+B = 9,80
        let plan = run(.cheapestWithStoreLimit, limit: .two).recommendation
        XCTAssertEqual(Set(plan?.storeIDs ?? []), ["B", "D"])
        XCTAssertEqual(plan?.total, Money(euros: 9.30))
        XCTAssertLessThanOrEqual(plan?.storeCount ?? 99, 2)
    }

    func testMaxThreeStoresEqualsUnlimitedOptimumHere() {
        let plan = run(.cheapestWithStoreLimit, limit: .three).recommendation
        XCTAssertEqual(Set(plan?.storeIDs ?? []), ["B", "C", "D"])
        XCTAssertEqual(plan?.total, Money(euros: 8.30))
    }

    func testStoreLimitIsNeverExceededAndMatchesBruteForce() {
        // Gegenprobe: Minimum über alle Paare, unabhängig berechnet.
        let table: [String: [String: Int]] = [
            "Milch": ["A": 100, "B": 80, "C": 120],
            "Brot": ["A": 200, "B": 250, "C": 150],
            "Käse": ["A": 300, "B": 350, "C": 320, "D": 200],
            "Kaffee": ["A": 500, "B": 400, "C": 600]
        ]
        let ids = ["A", "B", "C", "D"]
        var bestPair = Int.max
        for i in 0..<ids.count {
            for j in (i + 1)..<ids.count {
                let pair = [ids[i], ids[j]]
                let costs = table.values.map { row in pair.compactMap { row[$0] }.min() }
                if costs.contains(where: { $0 == nil }) { continue }
                bestPair = min(bestPair, costs.compactMap { $0 }.reduce(0, +))
            }
        }
        XCTAssertEqual(run(.cheapestWithStoreLimit, limit: .two).recommendation?.total.cents, bestPair)
    }

    func testExcludedStoresAreIgnored() {
        var restricted = stores
        restricted[1].isIncluded = false // B deaktiviert
        let plan = run(.singleStore, stores: restricted).recommendation
        XCTAssertEqual(plan?.storeIDs, ["A"])
        XCTAssertEqual(plan?.total, Money(euros: 11.00))
    }

    func testCheckedItemsAreNotOptimized() {
        var checkedItems = items
        checkedItems[3].isChecked = true // Kaffee abgehakt
        let result = run(.cheapestOverall, items: checkedItems)
        XCTAssertEqual(result.skippedCheckedItemCount, 1)
        XCTAssertNil(result.recommendation?.assignment["Kaffee"])
        XCTAssertEqual(result.recommendation?.total, Money(euros: 4.30))
    }

    func testOnlyOpenStoresExcludesClosedStores() {
        var withHours = stores
        // B ist montags geschlossen (TestSupport.now ist ein Montag, 10 Uhr).
        withHours[1].openingHours = [OpeningPeriod(weekday: 3, from: (8, 0), to: (20, 0))]
        var settings = TestSupport.settings(.singleStore)
        settings.onlyOpenStores = true
        let result = TestSupport.optimize(items, stores: withHours, products: products, prices: prices, settings: settings)
        XCTAssertEqual(result.recommendation?.storeIDs, ["A"])
        XCTAssertTrue(result.notices.contains { $0.kind == .storesExcluded })
    }

    // MARK: Kompromiss & Weg

    func testBalancedModeWeighsDistance() {
        // Bei 1 €/km gewinnt der nahe Laden: A allein 11,00 + 2 km = 13,00
        // schlägt B allein (10,80 + 4 km = 14,80) und B+D (9,30 + 10 km = 19,30).
        var settings = TestSupport.settings(.balanced, limit: .unlimited)
        settings.costPerKilometer = Money(euros: 1)
        let expensiveKm = TestSupport.optimize(items, stores: stores, products: products, prices: prices, settings: settings)
        XCTAssertEqual(expensiveKm.recommendation?.storeIDs, ["A"])

        // Bei 0 €/km entspricht der Kompromiss dem günstigsten Gesamtpreis.
        settings.costPerKilometer = .zero
        let freeKm = TestSupport.optimize(items, stores: stores, products: products, prices: prices, settings: settings)
        XCTAssertEqual(freeKm.recommendation?.total, Money(euros: 8.30))
    }

    func testShortestRouteAlternative() {
        let result = run(.cheapestOverall)
        let shortest = result.alternatives.first { $0.kinds.contains(.shortestRoute) }
        // Volle Abdeckung mit kürzestem Weg: nur A (1 km entfernt) → 2 km Rundweg.
        XCTAssertEqual(shortest?.plan.storeIDs, ["A"])
        XCTAssertEqual(shortest?.plan.route.distanceKm ?? 0, 2, accuracy: 0.0001)
    }

    func testAlternativesContainOneTwoAndThreeStoreVariants() {
        let result = run(.cheapestWithStoreLimit, limit: .two)
        let byKind = result.alternatives.flatMap { alternative in alternative.kinds.map { ($0, alternative) } }
        let one = byKind.first { $0.0 == .bestWithStores(1) }?.1
        let two = byKind.first { $0.0 == .bestWithStores(2) }?.1
        let three = byKind.first { $0.0 == .bestWithStores(3) }?.1
        XCTAssertEqual(one?.plan.total, Money(euros: 10.80))
        XCTAssertEqual(two?.plan.total, Money(euros: 9.30))
        XCTAssertEqual(two?.isSameAsRecommendation, true)
        XCTAssertEqual(three?.plan.total, Money(euros: 8.30))
    }

    func testRouteOrderFromHomeDistances() {
        let route = RoutePlanner().route(for: [stores[2], stores[0]], home: nil)
        XCTAssertEqual(route.orderedStores.map(\.id), ["A", "C"])
        // 1 (hin) + (1+3)/2 (zwischen) + 3 (zurück) = 6
        XCTAssertEqual(route.distanceKm, 6, accuracy: 0.0001)
        XCTAssertEqual(route.basis, .homeDistances)
    }

    func testRouteFromCoordinatesStartsWithNearestStore() {
        let home = GeoPoint(latitude: 51.0, longitude: 9.0)
        let near = TestSupport.store("near", location: GeoPoint(latitude: 51.01, longitude: 9.0))
        let far = TestSupport.store("far", location: GeoPoint(latitude: 51.05, longitude: 9.0))
        let route = RoutePlanner().route(for: [far, near], home: home)
        XCTAssertEqual(route.orderedStores.map(\.id), ["near", "far"])
        XCTAssertEqual(route.basis, .coordinates)
        // Hin- und Rückweg zum weiter entfernten Laden: 2 × 5,56 km × 1,3.
        XCTAssertEqual(route.distanceKm, 2 * home.distanceKm(to: far.location!) * 1.3, accuracy: 0.001)
    }

    func testCombinations() {
        XCTAssertEqual(ShoppingOptimizer.combinations(of: [1, 2, 3, 4], size: 2).count, 6)
        XCTAssertEqual(ShoppingOptimizer.combinations(of: [1, 2, 3], size: 3), [[1, 2, 3]])
        XCTAssertTrue(ShoppingOptimizer.combinations(of: [1, 2], size: 3).isEmpty)
    }
}
