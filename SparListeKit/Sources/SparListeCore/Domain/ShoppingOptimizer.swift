import Foundation

/// Berechnet die günstigste praktikable Einkaufsaufteilung.
///
/// Verfahren (exakt, kein Näherungsverfahren für die Preisoptimierung):
/// 1. Jeder offene Listeneintrag wird analysiert (`ItemAnalyzer`): passende Produkte,
///    Ausschlüsse, Markenvorgaben, Präferenzen und die beste Option je Laden.
/// 2. Für eine Ladenmenge S kostet ein Eintrag das Minimum seiner Optionen in S.
/// 3. Es werden alle Ladenmengen bis zur maximalen Ladenanzahl aufgezählt und lexikografisch
///    verglichen: (a) möglichst viele abgedeckte Einträge, (b) Zielwert (Preis, Preis + Weg
///    oder Weg), (c) Gesamtpreis, (d) weniger Läden, (e) kürzerer Weg, (f) Store-IDs.
///    Ohne Ladenlimit wird beim Preisziel direkt jeder Eintrag dem günstigsten Laden
///    zugeordnet – das ist ebenfalls optimal.
public struct ShoppingOptimizer: Sendable {
    enum Objective: Sendable {
        case price
        case balanced(costPerKm: Money)
        case distance
    }

    public var resolver: PriceResolver
    public var routePlanner: RoutePlanner
    /// Obergrenze der Ladenanzahl bei unbegrenzter Aufzählung (Weg-/Kompromissziel) mit sehr vielen Läden.
    public var maxEnumeratedStoresWhenUnlimited: Int

    public init(
        resolver: PriceResolver = PriceResolver(),
        routePlanner: RoutePlanner = RoutePlanner(),
        maxEnumeratedStoresWhenUnlimited: Int = 4
    ) {
        self.resolver = resolver
        self.routePlanner = routePlanner
        self.maxEnumeratedStoresWhenUnlimited = maxEnumeratedStoresWhenUnlimited
    }

    public func optimize(
        items: [ShoppingListItem],
        stores: [Store],
        catalog: Catalog,
        prices: [PriceEntry],
        settings: OptimizationSettings,
        at date: Date = Date()
    ) -> OptimizationResult {
        let openItems = items.filter { !$0.isChecked }
        var notices: [ResultNotice] = []

        // Berücksichtigte Läden.
        var eligibleStores = stores.filter(\.isIncluded)
        if settings.onlyOpenStores {
            let calendar = resolver.validity.calendar
            let closed = eligibleStores.filter { $0.isOpen(at: date, calendar: calendar) == false }
            if !closed.isEmpty {
                eligibleStores.removeAll { store in closed.contains { $0.id == store.id } }
                notices.append(ResultNotice(
                    kind: .storesExcluded,
                    message: "Aktuell geschlossen und daher nicht berücksichtigt: \(closed.map(\.name).joined(separator: ", "))."
                ))
            }
        }

        let analyzer = ItemAnalyzer(catalog: catalog, resolver: resolver, offerExpiryWarningDays: settings.offerExpiryWarningDays)
        let analyses = openItems.map { analyzer.analyze($0, stores: eligibleStores, prices: prices, at: date) }
        let purchasable = analyses.filter(\.isPurchasable)
        let usefulStoreIDs = Set(purchasable.flatMap { $0.bestOptionByStore.keys })
        let candidates = eligibleStores.filter { usefulStoreIDs.contains($0.id) }.sorted { $0.id < $1.id }

        let context = SearchContext(analyses: purchasable, home: settings.homeLocation, planner: routePlanner)

        // Empfehlung gemäß Modus.
        let recommendation: ShoppingPlan?
        switch settings.mode {
        case .cheapestOverall:
            recommendation = bestPlan(context, candidates: candidates, maxStores: nil, objective: .price)
        case .cheapestWithStoreLimit:
            recommendation = bestPlan(context, candidates: candidates, maxStores: settings.storeLimit.maxCount, objective: .price)
        case .singleStore:
            recommendation = bestPlan(context, candidates: candidates, maxStores: 1, objective: .price)
        case .balanced:
            recommendation = bestPlan(context, candidates: candidates, maxStores: settings.storeLimit.maxCount, objective: .balanced(costPerKm: settings.costPerKilometer))
        }

        // Alternativen.
        var alternatives: [PlanAlternative] = []
        func addAlternative(_ kind: PlanAlternative.Kind, _ plan: ShoppingPlan?) {
            guard let plan else { return }
            // Identische Varianten werden zusammengeführt (z. B. „1 Laden“ = „kürzester Weg“).
            if let index = alternatives.firstIndex(where: { $0.plan.isEquivalent(to: plan) }) {
                alternatives[index].kinds.append(kind)
                return
            }
            alternatives.append(PlanAlternative(
                kinds: [kind],
                plan: plan,
                isSameAsRecommendation: recommendation.map { $0.isEquivalent(to: plan) } ?? false
            ))
        }
        let bestSingle = bestPlan(context, candidates: candidates, maxStores: 1, objective: .price)
        addAlternative(.bestWithStores(1), bestSingle)
        for count in 2...3 where candidates.count >= count {
            addAlternative(.bestWithStores(count), bestPlan(context, candidates: candidates, maxStores: count, objective: .price))
        }
        if candidates.count > 3 {
            addAlternative(.cheapestOverall, bestPlan(context, candidates: candidates, maxStores: nil, objective: .price))
        }
        addAlternative(.shortestRoute, bestPlan(context, candidates: candidates, maxStores: settings.effectiveStoreLimit, objective: .distance))
        if settings.mode != .balanced {
            addAlternative(.balanced, bestPlan(context, candidates: candidates, maxStores: settings.effectiveStoreLimit, objective: .balanced(costPerKm: settings.costPerKilometer)))
        }

        // Ersparnis gegenüber der besten Ein-Laden-Lösung.
        var savings: SavingsSummary?
        if let recommendation, let bestSingle {
            savings = Self.savings(of: recommendation, comparedTo: bestSingle)
        }

        let unavailable = analyses.filter { !$0.isPurchasable }.map {
            UnavailableItem(item: $0.item, issues: $0.issues, alternatives: $0.alternatives)
        }

        notices += Self.notices(for: recommendation, analyses: purchasable, calendar: resolver.validity.calendar)

        return OptimizationResult(
            settings: settings,
            calculatedAt: date,
            recommendation: recommendation,
            alternatives: alternatives,
            unavailableItems: unavailable,
            savings: savings,
            notices: notices,
            skippedCheckedItemCount: items.count - openItems.count,
            consideredStoreCount: eligibleStores.count,
            analyses: analyses
        )
    }

    // MARK: - Suche

    struct SearchContext {
        var analyses: [ItemAnalysis]
        var home: GeoPoint?
        var planner: RoutePlanner
    }

    func bestPlan(_ context: SearchContext, candidates: [Store], maxStores: Int?, objective: Objective) -> ShoppingPlan? {
        guard !candidates.isEmpty, !context.analyses.isEmpty else { return nil }
        let limit = min(maxStores ?? candidates.count, candidates.count)
        guard limit >= 1 else { return nil }

        // Preisziel ohne wirksames Limit: jeder Eintrag zum günstigsten Laden (optimal).
        if case .price = objective, limit == candidates.count {
            return plan(context, stores: candidates)
        }

        var effectiveLimit = limit
        if maxStores == nil && candidates.count > 12 {
            effectiveLimit = min(limit, maxEnumeratedStoresWhenUnlimited)
        }

        var best: (plan: ShoppingPlan, key: PlanKey)?
        for size in 1...effectiveLimit {
            for subset in Self.combinations(of: candidates, size: size) {
                let candidatePlan = plan(context, stores: subset)
                let key = PlanKey(plan: candidatePlan, objective: objective)
                if best == nil || key < best!.key {
                    best = (candidatePlan, key)
                }
            }
        }
        return best?.plan
    }

    /// Plan für eine feste Ladenmenge: jeder Eintrag zur günstigsten Option innerhalb der Menge.
    func plan(_ context: SearchContext, stores: [Store]) -> ShoppingPlan {
        let storeIDs = Set(stores.map(\.id))
        var linesByStore: [String: [PlanLine]] = [:]
        var uncovered: [ShoppingListItem] = []

        for analysis in context.analyses {
            let options = analysis.bestOptionByStore.values.filter { storeIDs.contains($0.storeID) }
            if let best = options.min(by: StoreOption.isBetter) {
                linesByStore[best.storeID, default: []].append(PlanLine(item: analysis.item, option: best))
            } else {
                uncovered.append(analysis.item)
            }
        }

        let usedStores = stores.filter { linesByStore[$0.id] != nil }
        let route = context.planner.route(for: usedStores, home: context.home)
        let stops = route.orderedStores.map { store in
            PlanStop(store: store, lines: linesByStore[store.id] ?? [])
        }
        return ShoppingPlan(stops: stops, route: route, uncoveredItems: uncovered)
    }

    struct PlanKey: Comparable {
        var covered: Int
        var objectiveValue: Double
        var total: Int
        var storeCount: Int
        var distance: Double
        var ids: String

        init(plan: ShoppingPlan, objective: Objective) {
            covered = plan.coveredItemCount
            total = plan.total.cents
            storeCount = plan.storeCount
            distance = plan.route.distanceKm
            ids = plan.storeIDs.sorted().joined(separator: ",")
            switch objective {
            case .price:
                objectiveValue = Double(total)
            case let .balanced(costPerKm):
                objectiveValue = Double(total) + plan.route.distanceKm * Double(costPerKm.cents)
            case .distance:
                objectiveValue = plan.route.distanceKm
            }
        }

        static func < (lhs: PlanKey, rhs: PlanKey) -> Bool {
            if lhs.covered != rhs.covered { return lhs.covered > rhs.covered }
            if abs(lhs.objectiveValue - rhs.objectiveValue) > 1e-9 { return lhs.objectiveValue < rhs.objectiveValue }
            if lhs.total != rhs.total { return lhs.total < rhs.total }
            if lhs.storeCount != rhs.storeCount { return lhs.storeCount < rhs.storeCount }
            if abs(lhs.distance - rhs.distance) > 1e-9 { return lhs.distance < rhs.distance }
            return lhs.ids < rhs.ids
        }
    }

    static func combinations<T>(of elements: [T], size: Int) -> [[T]] {
        guard size > 0, size <= elements.count else { return size == 0 ? [[]] : [] }
        var result: [[T]] = []
        var indices = Array(0..<size)
        while true {
            result.append(indices.map { elements[$0] })
            var position = size - 1
            while position >= 0 && indices[position] == elements.count - size + position {
                position -= 1
            }
            if position < 0 { break }
            indices[position] += 1
            for next in (position + 1)..<size {
                indices[next] = indices[next - 1] + 1
            }
        }
        return result
    }

    // MARK: - Ersparnis & Hinweise

    /// Ersparnis auf den Einträgen, die beide Pläne enthalten.
    public static func savings(of plan: ShoppingPlan, comparedTo reference: ShoppingPlan) -> SavingsSummary {
        var planSum = Money.zero
        var referenceSum = Money.zero
        var compared = 0
        var missing = 0
        for line in plan.lines {
            if let referenceCost = reference.cost(of: line.item.id) {
                planSum += line.lineTotal
                referenceSum += referenceCost
                compared += 1
            } else {
                missing += 1
            }
        }
        return SavingsSummary(
            referencePlan: reference,
            amount: referenceSum - planSum,
            comparedItemCount: compared,
            itemsMissingInReference: missing
        )
    }

    static func notices(for plan: ShoppingPlan?, analyses: [ItemAnalysis], calendar: Calendar) -> [ResultNotice] {
        var notices: [ResultNotice] = []
        guard let plan else { return notices }

        if plan.lines.contains(where: { $0.option.source == .sampleData }) {
            notices.append(ResultNotice(kind: .sampleData, message: "Die verwendeten Preise sind lokal gepflegte Beispieldaten und keine echten Marktpreise."))
        }
        for stop in plan.stops {
            for line in stop.lines {
                let product = line.option.product.name
                if line.option.offerEndsSoon, let until = line.option.offerValidUntil {
                    notices.append(ResultNotice(
                        kind: .offerEndsSoon,
                        message: "Angebot „\(product)“ bei \(stop.store.name) gilt nur noch bis \(DateText.dayMonth(until, calendar: calendar))"
                    ))
                }
                switch line.option.freshness {
                case .outdated:
                    notices.append(ResultNotice(kind: .outdatedPrice, message: "Preis für „\(product)“ bei \(stop.store.name) ist veraltet – bitte prüfen."))
                case .estimated:
                    notices.append(ResultNotice(kind: .estimatedPrice, message: "Preis für „\(product)“ bei \(stop.store.name) ist geschätzt."))
                case .current:
                    break
                }
                if line.option.resolvedPrice.entry.availability == .limited {
                    notices.append(ResultNotice(kind: .limitedAvailability, message: "„\(product)“ ist bei \(stop.store.name) nur begrenzt verfügbar."))
                }
            }
        }
        for analysis in analyses {
            for issue in analysis.issues where !issue.blocksPurchase {
                let kind: ResultNotice.Kind
                if case .brandSubstituted = issue { kind = .brandSubstitution } else { kind = .preference }
                notices.append(ResultNotice(kind: kind, message: "\(analysis.item.query): \(issue.message)"))
            }
        }
        return notices
    }
}

/// Plattformunabhängige Datumsdarstellung (ohne `DateFormatter`-Locale-Abhängigkeiten).
public enum DateText {
    public static func dayMonth(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.day, .month], from: date)
        let day = c.day ?? 0
        let month = c.month ?? 0
        return "\(day < 10 ? "0" : "")\(day).\(month < 10 ? "0" : "")\(month)."
    }

    public static func dayMonthYear(_ date: Date, calendar: Calendar = .current) -> String {
        let year = calendar.component(.year, from: date)
        return "\(dayMonth(date, calendar: calendar))\(year)"
    }
}
