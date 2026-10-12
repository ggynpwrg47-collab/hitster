import SwiftUI
import SparListeCore

// MARK: - Fehler-Alert

extension View {
    /// Zeigt einen Alert, solange `message` nicht `nil` ist.
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Fehler",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { isPresented in if !isPresented { message.wrappedValue = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

// MARK: - Zustände

struct LoadingStateView: View {
    let text: String

    var body: some View {
        ProgressView(text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Etwas ist schiefgelaufen", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Erneut versuchen", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Badges

struct BadgeView: View {
    let text: String
    let color: Color
    var systemImage: String?

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(color)
        .background(color.opacity(0.14), in: Capsule())
    }
}

struct FreshnessBadge: View {
    let freshness: PriceFreshness

    var body: some View {
        switch freshness {
        case .current:
            BadgeView(text: freshness.displayName, color: .green, systemImage: "checkmark.seal")
        case .estimated:
            BadgeView(text: freshness.displayName, color: .orange, systemImage: "questionmark.circle")
        case .outdated:
            BadgeView(text: freshness.displayName, color: .red, systemImage: "clock.badge.exclamationmark")
        }
    }
}

struct OfferBadge: View {
    let validUntil: Date?
    var endsSoon: Bool = false

    var body: some View {
        if let validUntil {
            BadgeView(
                text: "Aktion bis \(DateText.dayMonth(validUntil))",
                color: endsSoon ? .red : .pink,
                systemImage: endsSoon ? "timer" : "percent"
            )
        } else {
            BadgeView(text: "Aktion", color: .pink, systemImage: "percent")
        }
    }
}

struct SourceBadge: View {
    let source: PriceSource

    var body: some View {
        switch source {
        case .sampleData:
            BadgeView(text: "Beispieldaten", color: .purple, systemImage: "flask")
        case .estimate:
            BadgeView(text: "Schätzung", color: .orange)
        case .manualEntry:
            BadgeView(text: "Manuell", color: .blue)
        case .imported:
            BadgeView(text: "Import", color: .teal)
        }
    }
}

/// Deutlicher Hinweis, dass die Preise keine echten Marktpreise sind.
struct SampleDataNotice: View {
    var body: some View {
        Label {
            Text("Die mitgelieferten Preise und Angebote sind **erfundene Beispieldaten**. Echte Preise kannst du unter „Preise“ selbst erfassen oder per JSON importieren.")
                .font(.footnote)
        } icon: {
            Image(systemName: "flask")
                .foregroundStyle(Color.purple)
        }
    }
}

// MARK: - Eingabehilfen

enum DecimalInput {
    /// Liest „1,29“ oder „1.29“ als Zahl.
    static func parse(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    static func format(_ value: Double?) -> String {
        guard let value else { return "" }
        return Quantity.formatNumber(value)
    }
}

extension StoreLimit {
    var shortLabel: String {
        switch self {
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .unlimited: return "∞"
        }
    }
}

extension OptimizationMode {
    var explanation: String {
        switch self {
        case .cheapestOverall:
            return "Jedes Produkt wird dort gekauft, wo es am günstigsten ist – unabhängig von der Ladenanzahl."
        case .cheapestWithStoreLimit:
            return "Günstigste Aufteilung, ohne die maximale Anzahl an Läden zu überschreiten."
        case .singleStore:
            return "Alles in einem Laden: der Laden mit den meisten verfügbaren Produkten zum niedrigsten Preis."
        case .balanced:
            return "Preis plus bewertete Wegstrecke (Wegkosten pro km) – innerhalb der maximalen Ladenanzahl."
        }
    }
}

extension Date {
    /// Minuten seit Mitternacht (für Öffnungszeiten).
    var minutesSinceMidnight: Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func todayAt(minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }
}
