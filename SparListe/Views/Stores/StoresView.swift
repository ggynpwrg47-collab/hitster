import SwiftUI
import SparListeCore
import SparListeFeatures

/// Läden verwalten (aktivieren, bevorzugen, bearbeiten) und Berechnung einstellen.
@MainActor
struct StoresView: View {
    let dependencies: AppDependencies
    @State private var viewModel: StoresViewModel
    @State private var editingStore: Store?
    @State private var confirmReset = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: StoresViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Läden")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            ForEach(StoreChain.allCases) { chain in
                                Button(chain.displayName) {
                                    editingStore = viewModel.newStoreTemplate(chain: chain)
                                }
                            }
                        } label: {
                            Label("Laden hinzufügen", systemImage: "plus")
                        }
                    }
                }
                .sheet(item: $editingStore) { store in
                    NavigationStack {
                        StoreEditorView(store: store, isOpenNow: viewModel.isOpenNow(store)) { updated in
                            Task { await viewModel.save(updated) }
                        }
                    }
                }
                .confirmationDialog("Alle Daten auf die Beispieldaten zurücksetzen?", isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("Zurücksetzen", role: .destructive) {
                        Task { await viewModel.resetSampleData() }
                    }
                } message: {
                    Text("Eigene Listen, Läden, Produkte und Preise werden dabei gelöscht.")
                }
                .errorAlert($viewModel.actionError)
                .onAppear {
                    Task { await viewModel.load() }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingStateView(text: "Lade Läden …")
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await viewModel.load() }
            }
        case .loaded:
            Form {
                settingsSection
                storesSection
                if viewModel.canResetSampleData {
                    Section {
                        Button("Beispieldaten wiederherstellen", role: .destructive) {
                            confirmReset = true
                        }
                    } footer: {
                        Text("Setzt Läden, Produkte, Preise, Angebote und Beispiellisten auf den Auslieferungszustand zurück (Angebote werden ab heute neu datiert).")
                    }
                }
            }
        }
    }

    private var settingsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Maximal zu besuchende Läden")
                Picker("Maximal zu besuchende Läden", selection: Binding(
                    get: { viewModel.settings.storeLimit },
                    set: { newValue in Task { await viewModel.setStoreLimit(newValue) } }
                )) {
                    ForEach(StoreLimit.allCases) { limit in
                        Text(limit.shortLabel).tag(limit)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.vertical, 4)

            Picker("Optimierung", selection: Binding(
                get: { viewModel.settings.mode },
                set: { newValue in Task { await viewModel.setMode(newValue) } }
            )) {
                ForEach(OptimizationMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            if viewModel.settings.mode == .balanced {
                Stepper(
                    "Wegkosten: \(viewModel.settings.costPerKilometer.formatted) / km",
                    value: Binding(
                        get: { viewModel.settings.costPerKilometer.cents },
                        set: { cents in
                            var settings = viewModel.settings
                            settings.costPerKilometer = Money(cents: cents)
                            Task { await viewModel.save(settings) }
                        }
                    ),
                    in: 0...200,
                    step: 5
                )
            }

            Toggle("Nur aktuell geöffnete Läden", isOn: Binding(
                get: { viewModel.settings.onlyOpenStores },
                set: { isOn in
                    var settings = viewModel.settings
                    settings.onlyOpenStores = isOn
                    Task { await viewModel.save(settings) }
                }
            ))
        } header: {
            Text("Berechnung")
        } footer: {
            Text(viewModel.settings.mode.explanation)
        }
    }

    private var storesSection: some View {
        Section {
            if viewModel.stores.isEmpty {
                Text("Noch keine Läden. Füge oben rechts einen Laden hinzu.")
                    .foregroundStyle(.secondary)
            }
            ForEach(viewModel.stores) { store in
                StoreRow(
                    store: store,
                    isOpenNow: viewModel.isOpenNow(store),
                    onIncludedChange: { included in Task { await viewModel.setIncluded(store, included) } }
                )
                .contentShape(Rectangle())
                .onTapGesture { editingStore = store }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await viewModel.delete(store) }
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        Task { await viewModel.setFavorite(store, !store.isFavorite) }
                    } label: {
                        Label(store.isFavorite ? "Nicht bevorzugen" : "Bevorzugen", systemImage: store.isFavorite ? "star.slash" : "star")
                    }
                    .tint(.yellow)
                }
            }
        } header: {
            Text("Meine Läden")
        } footer: {
            Text("\(viewModel.includedCount) von \(viewModel.stores.count) Läden werden in die Berechnung einbezogen. Antippen zum Bearbeiten.")
        }
    }
}

private struct StoreRow: View {
    let store: Store
    let isOpenNow: Bool?
    let onIncludedChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(store.name)
                        .font(.headline)
                    if store.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color.yellow)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    BadgeView(text: store.chain.displayName, color: .gray)
                    switch isOpenNow {
                    case .some(true):
                        BadgeView(text: "Geöffnet", color: .green)
                    case .some(false):
                        BadgeView(text: "Geschlossen", color: .red)
                    case .none:
                        BadgeView(text: "Öffnungszeiten fehlen", color: .gray)
                    }
                }
            }
            Spacer(minLength: 0)
            Toggle("In Berechnung einbeziehen", isOn: Binding(
                get: { store.isIncluded },
                set: { onIncludedChange($0) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 2)
        .opacity(store.isIncluded ? 1 : 0.6)
    }

    private var subtitle: String {
        var parts: [String] = []
        if !store.address.isEmpty { parts.append(store.address) }
        if let distance = store.distanceKm { parts.append("\(DecimalInput.format(distance)) km") }
        return parts.isEmpty ? "Keine Adresse hinterlegt" : parts.joined(separator: " · ")
    }
}
