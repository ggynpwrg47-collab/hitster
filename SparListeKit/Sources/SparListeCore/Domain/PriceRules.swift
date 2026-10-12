import Foundation

/// Prüft die Gültigkeit von Angeboten. Ein Angebot gilt vom Beginn des Tages
/// `validFrom` bis zum Ende des Tages `validUntil` (jeweils im Kalender des Geräts).
public struct OfferValidity: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func isValid(_ entry: PriceEntry, at date: Date) -> Bool {
        switch entry.kind {
        case .regular:
            return true
        case let .offer(from, until):
            let start = calendar.startOfDay(for: from)
            guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: until)) else {
                return false
            }
            return date >= start && date < end
        }
    }

    /// Ganze Kalendertage bis zum letzten Gültigkeitstag (0 = läuft heute ab).
    public func daysRemaining(_ entry: PriceEntry, at date: Date) -> Int? {
        guard let until = entry.offerValidUntil else { return nil }
        let today = calendar.startOfDay(for: date)
        let lastDay = calendar.startOfDay(for: until)
        return calendar.dateComponents([.day], from: today, to: lastDay).day
    }

    /// Angebot ist gültig und läuft innerhalb von `withinDays` Tagen ab.
    public func endsSoon(_ entry: PriceEntry, at date: Date, withinDays: Int) -> Bool {
        guard isValid(entry, at: date), let remaining = daysRemaining(entry, at: date) else { return false }
        return remaining <= withinDays
    }
}

/// Bestimmt, ob ein Preis als aktuell, geschätzt oder veraltet gekennzeichnet wird.
public struct PriceFreshnessPolicy: Sendable {
    /// Reguläre Preise, die älter sind, gelten als veraltet.
    public var maxAgeDays: Int

    public init(maxAgeDays: Int = 14) {
        self.maxAgeDays = maxAgeDays
    }

    public func freshness(of entry: PriceEntry, at date: Date) -> PriceFreshness {
        if entry.source == .estimate { return .estimated }
        // Ein aktuell gültiges Angebot ist per Definition aktuell (es hat einen Gültigkeitszeitraum).
        if entry.isOffer { return .current }
        let ageSeconds = date.timeIntervalSince(entry.observedAt)
        return ageSeconds > Double(maxAgeDays) * 86_400 ? .outdated : .current
    }
}

/// Effektiver Preis eines Produkts in einem Laden zu einem Zeitpunkt.
public struct ResolvedPrice: Hashable, Sendable {
    public var entry: PriceEntry
    /// Regulärer Preis, falls ein günstigeres Angebot gewählt wurde (für „statt“-Anzeige).
    public var regularPrice: Money?
    public var freshness: PriceFreshness

    public var price: Money { entry.price }
    public var isOffer: Bool { entry.isOffer }
}

/// Ermittelt aus allen Preiseinträgen eines Produkts in einem Laden den gültigen Preis.
///
/// Regeln:
/// - Angebote zählen nur, wenn sie zum Zeitpunkt gültig sind.
/// - Der zuletzt erfasste gültige Eintrag bestimmt die Verfügbarkeit.
/// - Unter den verfügbaren gültigen Einträgen gewinnt der niedrigste Preis.
public struct PriceResolver: Sendable {
    public var validity: OfferValidity
    public var freshnessPolicy: PriceFreshnessPolicy

    public init(validity: OfferValidity = OfferValidity(), freshnessPolicy: PriceFreshnessPolicy = PriceFreshnessPolicy()) {
        self.validity = validity
        self.freshnessPolicy = freshnessPolicy
    }

    public func resolve(_ entries: [PriceEntry], at date: Date) -> ResolvedPrice? {
        let valid = entries.filter { validity.isValid($0, at: date) }
        guard let latest = valid.max(by: { $0.observedAt < $1.observedAt }),
              latest.availability.isPurchasable else {
            return nil
        }
        let purchasable = valid.filter { $0.availability.isPurchasable }
        guard let best = purchasable.min(by: PriceResolver.isCheaper) else { return nil }
        let regular = purchasable
            .filter { !$0.isOffer }
            .max(by: { $0.observedAt < $1.observedAt })?
            .price
        return ResolvedPrice(
            entry: best,
            regularPrice: best.isOffer && regular.map({ $0 > best.price }) == true ? regular : nil,
            freshness: freshnessPolicy.freshness(of: best, at: date)
        )
    }

    static func isCheaper(_ lhs: PriceEntry, _ rhs: PriceEntry) -> Bool {
        if lhs.price != rhs.price { return lhs.price < rhs.price }
        // Bei Gleichstand: neuerer Eintrag, dann ID für Determinismus.
        if lhs.observedAt != rhs.observedAt { return lhs.observedAt > rhs.observedAt }
        return lhs.id < rhs.id
    }
}
