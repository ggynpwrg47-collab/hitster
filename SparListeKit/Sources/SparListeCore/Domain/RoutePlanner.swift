import Foundation

/// Grundlage der Wegberechnung – wird in der UI transparent angezeigt.
public enum RouteBasis: String, Codable, Sendable {
    /// Aus Koordinaten (Luftlinie × Umwegfaktor) berechnet.
    case coordinates
    /// Aus den gepflegten Entfernungen von zu Hause geschätzt.
    case homeDistances
    /// Für mindestens einen Laden fehlen Entfernungsangaben.
    case unknown

    public var displayName: String {
        switch self {
        case .coordinates: return "berechnet aus Koordinaten (Luftlinie × 1,3)"
        case .homeDistances: return "geschätzt aus Entfernungen"
        case .unknown: return "Entfernung unbekannt"
        }
    }
}

/// Rundweg ab zu Hause über die gewählten Läden.
public struct Route: Hashable, Sendable {
    public var orderedStores: [Store]
    /// Gesamtstrecke (hin und zurück) in km. Bei `basis == .unknown` eine Untergrenze.
    public var distanceKm: Double
    public var basis: RouteBasis
}

/// Plant die Reihenfolge der Läden und schätzt die Gesamtwegstrecke.
public struct RoutePlanner: Sendable {
    /// Faktor von Luftlinie auf Straßenweg.
    public var detourFactor: Double

    public init(detourFactor: Double = 1.3) {
        self.detourFactor = detourFactor
    }

    public func route(for stores: [Store], home: GeoPoint?) -> Route {
        guard !stores.isEmpty else { return Route(orderedStores: [], distanceKm: 0, basis: .homeDistances) }

        if let home, stores.allSatisfy({ $0.location != nil }) {
            return coordinateRoute(stores: stores, home: home)
        }

        // Schätzung aus Entfernungen: nach Entfernung aufsteigend anfahren.
        // Strecke zwischen zwei Läden ist unbekannt und wird mit dem Mittelwert
        // ihrer Entfernungen von zu Hause angenähert.
        let known = stores.allSatisfy { $0.distanceKm != nil }
        let ordered = stores.sorted { lhs, rhs in
            let l = lhs.distanceKm ?? .infinity
            let r = rhs.distanceKm ?? .infinity
            return l != r ? l < r : lhs.id < rhs.id
        }
        let distances = ordered.map { $0.distanceKm ?? 0 }
        var total = distances.first ?? 0
        for index in 1..<max(1, distances.count) {
            total += (distances[index - 1] + distances[index]) / 2
        }
        total += distances.last ?? 0
        return Route(orderedStores: ordered, distanceKm: total, basis: known ? .homeDistances : .unknown)
    }

    private func coordinateRoute(stores: [Store], home: GeoPoint) -> Route {
        func distance(_ a: GeoPoint, _ b: GeoPoint) -> Double { a.distanceKm(to: b) * detourFactor }
        func tourLength(_ order: [Store]) -> Double {
            var total = 0.0
            var current = home
            for store in order {
                let location = store.location!
                total += distance(current, location)
                current = location
            }
            return total + distance(current, home)
        }

        let sortedInput = stores.sorted { $0.id < $1.id }
        var bestOrder = sortedInput
        var bestLength = tourLength(sortedInput)
        if stores.count <= 7 {
            // Exakt über alle Reihenfolgen (max. 5040 Permutationen).
            for permutation in RoutePlanner.permutations(sortedInput) {
                let length = tourLength(permutation)
                if length < bestLength - 1e-9 {
                    bestLength = length
                    bestOrder = permutation
                }
            }
        } else {
            // Heuristik: nächster Nachbar.
            var remaining = sortedInput
            var order: [Store] = []
            var current = home
            while !remaining.isEmpty {
                let index = remaining.indices.min { distance(current, remaining[$0].location!) < distance(current, remaining[$1].location!) }!
                let next = remaining.remove(at: index)
                order.append(next)
                current = next.location!
            }
            bestOrder = order
            bestLength = tourLength(order)
        }
        // Rundwege sind in beide Richtungen gleich lang: mit dem näheren Laden beginnen.
        if let first = bestOrder.first?.location, let last = bestOrder.last?.location,
           bestOrder.count > 1, distance(home, last) < distance(home, first) - 1e-9 {
            bestOrder.reverse()
        }
        return Route(orderedStores: bestOrder, distanceKm: bestLength, basis: .coordinates)
    }

    static func permutations<T>(_ elements: [T]) -> [[T]] {
        guard elements.count > 1 else { return [elements] }
        var result: [[T]] = []
        for index in elements.indices {
            var rest = elements
            let head = rest.remove(at: index)
            for tail in permutations(rest) {
                result.append([head] + tail)
            }
        }
        return result
    }
}
