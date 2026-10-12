import SwiftUI
import SparListeCore
import SparListeFeatures

/// Ergebnis der Optimierung: Empfehlung, Route, Aufteilung, Hinweise, Alternativen.
@MainActor
struct OptimizationView: View {
    @State private var viewModel: OptimizationViewModel

    init(listID: UUID, dependencies: AppDependencies) {
        _viewModel = State(initialValue: OptimizationViewModel(listID: listID, dependencies: dependencies))
    }

    var body: some View {
        content
            .navigationTitle("Empfehlung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.calculate() }
                    } label: {
                        Label("Neu berechnen", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.state == .calculating)
                }
            }
            .errorAlert($viewModel.actionError)
            .task {
                if viewModel.state == .idle {
                    await viewModel.calculate()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .calculating:
            LoadingStateView(text: "Berechne günstigste Aufteilung …")
        case let .failed(message):
            ContentUnavailableView {
                Label("Berechnung nicht möglich", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Erneut versuchen") {
                    Task { await viewModel.calculate() }
                }
                .buttonStyle(.borderedProminent)
            }
        case let .result(result):
            ResultList(result: result, viewModel: viewModel)
        }
    }
}

@MainActor
private struct ResultList: View {
    let result: OptimizationResult
    let viewModel: OptimizationViewModel

    var body: some View {
        List {
            Section {
                SummaryView(result: result, plan: result.recommendation)
            }

            if !result.notices.isEmpty {
                Section("Hinweise") {
                    ForEach(result.notices) { notice in
                        NoticeRow(notice: notice)
                    }
                }
            }

            if let plan = result.recommendation {
                PlanSections(
                    plan: plan,
                    isChecked: { viewModel.isChecked($0) },
                    onToggle: { itemID in Task { await viewModel.toggleChecked(itemID) } },
                    progress: { viewModel.progress(for: $0) }
                )
            } else {
                Section {
                    Text("Keines der Produkte ist in den berücksichtigten Läden erhältlich.")
                        .foregroundStyle(.secondary)
                }
            }

            if !result.unavailableItems.isEmpty {
                Section {
                    ForEach(result.unavailableItems) { unavailable in
                        UnavailableRow(unavailable: unavailable, storeName: { viewModel.storeNames[$0] ?? $0 })
                    }
                } header: {
                    Label("Nicht verfügbar", systemImage: "xmark.octagon")
                } footer: {
                    Text("Diese Produkte sind in der Summe nicht enthalten.")
                }
            }

            if !result.alternatives.isEmpty {
                Section("Alternative Varianten") {
                    ForEach(result.alternatives) { alternative in
                        NavigationLink {
                            AlternativePlanView(alternative: alternative, recommendation: result.recommendation)
                        } label: {
                            AlternativeRow(alternative: alternative, recommendation: result.recommendation)
                        }
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preisquelle: \(viewModel.priceSourceName)")
                    Text("Berechnet am \(result.calculatedAt.formatted(date: .abbreviated, time: .shortened)) · Modus: \(result.settings.mode.displayName)")
                    Text("Nur aktuell gültige Angebote werden berücksichtigt.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Zusammenfassung

private struct SummaryView: View {
    let result: OptimizationResult
    let plan: ShoppingPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let plan {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gesamtpreis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(plan.total.formatted)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(PlanText.storeCount(plan))
                            .font(.headline)
                        Text(PlanText.distance(plan))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let savings = result.savings {
                    SavingsView(savings: savings)
                }

                Text(PlanText.route(plan))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if result.skippedCheckedItemCount > 0 {
                Text("\(result.skippedCheckedItemCount) bereits abgehakte Produkte wurden nicht berücksichtigt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SavingsView: View {
    let savings: SavingsSummary

    var body: some View {
        let reference = savings.referencePlan.stops.first?.store.name ?? "einem Laden"
        VStack(alignment: .leading, spacing: 4) {
            if savings.amount > .zero {
                Label {
                    Text("Du sparst **\(savings.amount.formatted)** gegenüber der besten Ein-Laden-Lösung (\(reference): \(savings.referencePlan.total.formatted)).")
                } icon: {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Color.green)
                }
            } else {
                Label {
                    Text("Die beste Ein-Laden-Lösung (\(reference)) ist bereits am günstigsten.")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                }
            }
            if !savings.isFullyComparable {
                Text("\(savings.itemsMissingInReference) Produkt(e) gibt es bei \(reference) nicht – die Ersparnis bezieht sich auf \(savings.comparedItemCount) vergleichbare Produkte.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }
}

private struct NoticeRow: View {
    let notice: ResultNotice

    var body: some View {
        Label {
            Text(notice.message)
                .font(.subheadline)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(color)
        }
    }

    private var icon: String {
        switch notice.kind {
        case .offerEndsSoon: return "timer"
        case .outdatedPrice: return "clock.badge.exclamationmark"
        case .estimatedPrice: return "questionmark.circle"
        case .preference: return "leaf"
        case .brandSubstitution: return "arrow.triangle.swap"
        case .sampleData: return "flask"
        case .storesExcluded: return "moon.zzz"
        case .limitedAvailability: return "shippingbox"
        }
    }

    private var color: Color {
        switch notice.kind {
        case .offerEndsSoon, .outdatedPrice: return .red
        case .estimatedPrice, .brandSubstitution, .limitedAvailability: return .orange
        case .sampleData: return .purple
        case .preference, .storesExcluded: return .secondary
        }
    }
}

// MARK: - Plan

/// Abschnitte je Laden in Besuchsreihenfolge. Wiederverwendbar für Empfehlung und Alternativen.
@MainActor
struct PlanSections: View {
    let plan: ShoppingPlan
    var isChecked: (UUID) -> Bool = { _ in false }
    var onToggle: ((UUID) -> Void)?
    var progress: ((PlanStop) -> (done: Int, total: Int))?

    var body: some View {
        ForEach(Array(plan.stops.enumerated()), id: \.element.id) { index, stop in
            Section {
                ForEach(stop.lines) { line in
                    PlanLineRow(line: line, isChecked: isChecked(line.item.id), onToggle: toggleAction(for: line.item.id))
                }
                HStack {
                    Text("Zwischensumme")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(stop.subtotal.formatted)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            } header: {
                HStack {
                    Text("\(index + 1). \(stop.store.name)")
                    Spacer()
                    if let progress {
                        let value = progress(stop)
                        Text("\(value.done)/\(value.total)")
                            .monospacedDigit()
                    }
                }
            } footer: {
                if !stop.store.address.isEmpty {
                    Text(stop.store.address)
                }
            }
        }

        if !plan.uncoveredItems.isEmpty {
            Section {
                ForEach(plan.uncoveredItems) { item in
                    Text(item.title)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("In dieser Variante nicht erhältlich")
            } footer: {
                Text("Diese Produkte gibt es nur in anderen Läden.")
            }
        }
    }

    private func toggleAction(for itemID: UUID) -> (() -> Void)? {
        guard let onToggle else { return nil }
        return { onToggle(itemID) }
    }
}

private struct PlanLineRow: View {
    let line: PlanLine
    let isChecked: Bool
    let onToggle: (() -> Void)?

    private var option: StoreOption { line.option }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let onToggle {
                Button(action: onToggle) {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isChecked ? Color.green : Color.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isChecked ? "Abhaken rückgängig" : "Abhaken")
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(line.item.query)
                    .font(.body.weight(.medium))
                    .strikethrough(isChecked)
                Text("\(option.packageCount) × \(option.product.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(sizeAndUnitPrice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    if option.isOffer {
                        OfferBadge(validUntil: option.offerValidUntil, endsSoon: option.offerEndsSoon)
                    }
                    FreshnessBadge(freshness: option.freshness)
                    if option.source == .sampleData {
                        SourceBadge(source: option.source)
                    }
                }
            }
            .opacity(isChecked ? 0.5 : 1)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(option.lineTotal.formatted)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                if option.packageCount > 1 {
                    Text("je \(option.packagePrice.formatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let regular = option.regularPrice {
                    Text("statt \(regular.formatted)")
                        .font(.caption)
                        .strikethrough()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var sizeAndUnitPrice: String {
        var text = "Packung \(option.product.packageSize.formatted)"
        if let unitPrice = option.unitPrice {
            text += " · \(unitPrice.formatted)"
        }
        return text
    }
}

private struct UnavailableRow: View {
    let unavailable: UnavailableItem
    let storeName: (String) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(unavailable.item.title)
                .font(.body.weight(.medium))
            Text(unavailable.reason)
                .font(.subheadline)
                .foregroundStyle(Color.red)
            if !unavailable.alternatives.isEmpty {
                Text("Alternativen:")
                    .font(.caption.weight(.semibold))
                    .padding(.top, 2)
                ForEach(unavailable.alternatives, id: \.self) { option in
                    Text(alternativeText(option))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Tipp: Im Produkt „Alternative einplanen“ aktivieren, um automatisch auszuweichen.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func alternativeText(_ option: StoreOption) -> String {
        var text = "• \(option.product.name) bei \(storeName(option.storeID)) – \(option.packagePrice.formatted)"
        if let unitPrice = option.unitPrice {
            text += " (\(unitPrice.formatted))"
        }
        return text
    }
}

// MARK: - Alternativen

private struct AlternativeRow: View {
    let alternative: PlanAlternative
    let recommendation: ShoppingPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(alternative.title)
                    .font(.subheadline.weight(.semibold))
                if alternative.isSameAsRecommendation {
                    BadgeView(text: "Empfehlung", color: .green)
                }
            }
            Text(PlanText.storeSequence(alternative.plan))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text(alternative.plan.total.formatted)
                    .monospacedDigit()
                if let recommendation, !alternative.isSameAsRecommendation {
                    let difference = alternative.plan.total - recommendation.total
                    Text(PriceDifference.short(difference))
                        .font(.caption)
                        .foregroundStyle(difference > .zero ? Color.red : Color.green)
                }
                Spacer()
                Text(PlanText.distance(alternative.plan))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if alternative.plan.coveredItemCount < (recommendation?.coveredItemCount ?? 0) {
                Text("Deckt nur \(alternative.plan.coveredItemCount) von \(recommendation?.coveredItemCount ?? 0) Produkten ab")
                    .font(.caption)
                    .foregroundStyle(Color.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

@MainActor
struct AlternativePlanView: View {
    let alternative: PlanAlternative
    let recommendation: ShoppingPlan?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(alternative.plan.total.formatted)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(PlanText.storesAndDistance(alternative.plan))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let recommendation, !alternative.isSameAsRecommendation {
                        Text(PriceDifference.long(alternative.plan.total - recommendation.total))
                            .font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
            }
            PlanSections(plan: alternative.plan)
        }
        .navigationTitle(alternative.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Texte

enum PlanText {
    static func storeCount(_ plan: ShoppingPlan) -> String {
        plan.storeCount == 1 ? "1 Laden" : "\(plan.storeCount) Läden"
    }

    static func distance(_ plan: ShoppingPlan) -> String {
        let rounded = (plan.route.distanceKm * 10).rounded() / 10
        return "ca. \(DecimalInput.format(rounded)) km"
    }

    static func storeSequence(_ plan: ShoppingPlan) -> String {
        plan.stops.map { $0.store.name }.joined(separator: " → ")
    }

    static func route(_ plan: ShoppingPlan) -> String {
        "Route: \(storeSequence(plan)) (\(plan.route.basis.displayName))"
    }

    static func storesAndDistance(_ plan: ShoppingPlan) -> String {
        "\(storeCount(plan)) · \(distance(plan)) (\(plan.route.basis.displayName))"
    }
}

enum PriceDifference {
    static func short(_ difference: Money) -> String {
        difference >= .zero ? "+\(difference.formatted)" : difference.formatted
    }

    static func long(_ difference: Money) -> String {
        if difference >= .zero {
            return "\(difference.formatted) teurer als die Empfehlung"
        }
        return "\((Money.zero - difference).formatted) günstiger als die Empfehlung"
    }
}
