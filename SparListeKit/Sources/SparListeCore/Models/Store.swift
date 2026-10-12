import Foundation

/// Geografischer Punkt (WGS84). Optional – ermöglicht eine genauere Wegberechnung.
public struct GeoPoint: Hashable, Codable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Luftlinie in Kilometern (Haversine).
    public func distanceKm(to other: GeoPoint) -> Double {
        let earthRadiusKm = 6371.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

/// Öffnungszeit an einem Wochentag. `weekday` folgt `Calendar`: 1 = Sonntag … 7 = Samstag.
public struct OpeningPeriod: Hashable, Codable, Sendable {
    public var weekday: Int
    /// Minuten seit Mitternacht.
    public var opensAt: Int
    public var closesAt: Int

    public init(weekday: Int, opensAt: Int, closesAt: Int) {
        self.weekday = weekday
        self.opensAt = opensAt
        self.closesAt = closesAt
    }

    public init(weekday: Int, from: (Int, Int), to: (Int, Int)) {
        self.init(weekday: weekday, opensAt: from.0 * 60 + from.1, closesAt: to.0 * 60 + to.1)
    }

    public static let weekdayNames = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]

    public var formatted: String {
        let name = (1...7).contains(weekday) ? OpeningPeriod.weekdayNames[weekday - 1] : "?"
        return "\(name) \(OpeningPeriod.time(opensAt))–\(OpeningPeriod.time(closesAt))"
    }

    static func time(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return "\(h < 10 ? "0" : "")\(h):\(m < 10 ? "0" : "")\(m)"
    }

    /// Mo–Sa mit denselben Zeiten, sonntags geschlossen (typisch in Deutschland).
    public static func mondayToSaturday(from: (Int, Int), to: (Int, Int)) -> [OpeningPeriod] {
        (2...7).map { OpeningPeriod(weekday: $0, from: from, to: to) }
    }
}

/// Ein konkreter Supermarkt.
public struct Store: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var chain: StoreChain
    public var name: String
    /// Adresse oder PLZ (frei eingebbar).
    public var address: String
    /// Entfernung von zu Hause in km (manuell gepflegt).
    public var distanceKm: Double?
    public var location: GeoPoint?
    public var openingHours: [OpeningPeriod]
    public var isFavorite: Bool
    /// Wird der Laden in die Berechnung einbezogen?
    public var isIncluded: Bool

    public init(
        id: String,
        chain: StoreChain,
        name: String,
        address: String = "",
        distanceKm: Double? = nil,
        location: GeoPoint? = nil,
        openingHours: [OpeningPeriod] = [],
        isFavorite: Bool = false,
        isIncluded: Bool = true
    ) {
        self.id = id
        self.chain = chain
        self.name = name
        self.address = address
        self.distanceKm = distanceKm
        self.location = location
        self.openingHours = openingHours
        self.isFavorite = isFavorite
        self.isIncluded = isIncluded
    }

    /// Ob der Laden zum Zeitpunkt `date` geöffnet ist. `nil`, wenn keine Öffnungszeiten gepflegt sind.
    public func isOpen(at date: Date, calendar: Calendar = .current) -> Bool? {
        guard !openingHours.isEmpty else { return nil }
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = components.weekday else { return nil }
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return openingHours.contains { $0.weekday == weekday && minutes >= $0.opensAt && minutes < $0.closesAt }
    }
}
