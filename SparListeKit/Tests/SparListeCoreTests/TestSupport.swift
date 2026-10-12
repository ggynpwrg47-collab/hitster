import Foundation
@testable import SparListeCore

/// Gemeinsame Hilfen für deterministische Tests (fester Kalender und Zeitpunkt).
enum TestSupport {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    /// Montag, 12.10.2026, 10:00 Uhr.
    static let now = date(2026, 10, 12, hour: 10)

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now)!
    }

    static var resolver: PriceResolver {
        PriceResolver(validity: OfferValidity(calendar: calendar))
    }

    static var optimizer: ShoppingOptimizer {
        ShoppingOptimizer(resolver: resolver)
    }

    static func store(_ id: String, _ chain: StoreChain = .other, distance: Double? = nil, location: GeoPoint? = nil, included: Bool = true) -> Store {
        Store(id: id, chain: chain, name: id, distanceKm: distance, location: location, isIncluded: included)
    }

    static func product(_ id: String, generic: String, brand: String? = nil, size: Quantity = Quantity(1, .piece),
                        organic: Bool = false, ingredients: [String] = []) -> Product {
        Product(id: id, name: id, genericName: generic, brandID: brand, packageSize: size, isOrganic: organic, ingredients: ingredients)
    }

    private static var counter = 0

    static func price(_ product: String, _ store: String, _ euros: Double,
                      availability: Availability = .available, source: PriceSource = .manualEntry,
                      observedDaysAgo: Int = 1) -> PriceEntry {
        counter += 1
        return PriceEntry(id: "p\(counter)", productID: product, storeID: store, price: Money(euros: euros),
                          availability: availability, source: source, observedAt: day(-observedDaysAgo))
    }

    static func offer(_ product: String, _ store: String, _ euros: Double, from: Int, until: Int) -> PriceEntry {
        counter += 1
        return PriceEntry(id: "o\(counter)", productID: product, storeID: store, price: Money(euros: euros),
                          kind: .offer(validFrom: day(from), validUntil: day(until)),
                          source: .manualEntry, observedAt: day(min(from, 0)))
    }

    static func settings(_ mode: OptimizationMode, limit: StoreLimit = .unlimited, home: GeoPoint? = nil) -> OptimizationSettings {
        OptimizationSettings(mode: mode, storeLimit: limit, homeLocation: home)
    }

    static func optimize(_ items: [ShoppingListItem], stores: [Store], products: [Product], brands: [Brand] = [],
                         prices: [PriceEntry], settings: OptimizationSettings) -> OptimizationResult {
        optimizer.optimize(items: items, stores: stores, catalog: Catalog(products: products, brands: brands),
                           prices: prices, settings: settings, at: now)
    }
}

extension ShoppingPlan {
    /// Zuordnung Suchbegriff → Store-ID, für kompakte Assertions.
    var assignment: [String: String] {
        Dictionary(uniqueKeysWithValues: lines.map { ($0.item.query, $0.option.storeID) })
    }
}
