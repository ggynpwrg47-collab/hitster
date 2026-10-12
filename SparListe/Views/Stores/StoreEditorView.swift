import SwiftUI
import SparListeCore

/// Laden anlegen oder bearbeiten.
@MainActor
struct StoreEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let isOpenNow: Bool?
    let onSave: (Store) -> Void

    @State private var draft: Store
    @State private var distanceText: String
    @State private var latitudeText: String
    @State private var longitudeText: String
    @State private var hasOpeningHours: Bool
    @State private var weekdayOpen: Date
    @State private var weekdayClose: Date
    @State private var openOnSunday: Bool
    @State private var sundayOpen: Date
    @State private var sundayClose: Date

    init(store: Store, isOpenNow: Bool?, onSave: @escaping (Store) -> Void) {
        self.isOpenNow = isOpenNow
        self.onSave = onSave
        _draft = State(initialValue: store)
        _distanceText = State(initialValue: DecimalInput.format(store.distanceKm))
        _latitudeText = State(initialValue: store.location.map { String($0.latitude) } ?? "")
        _longitudeText = State(initialValue: store.location.map { String($0.longitude) } ?? "")
        _hasOpeningHours = State(initialValue: !store.openingHours.isEmpty)
        let weekday = store.openingHours.first { $0.weekday != 1 }
        let sunday = store.openingHours.first { $0.weekday == 1 }
        _weekdayOpen = State(initialValue: Date.todayAt(minutes: weekday?.opensAt ?? 7 * 60))
        _weekdayClose = State(initialValue: Date.todayAt(minutes: weekday?.closesAt ?? 21 * 60))
        _openOnSunday = State(initialValue: sunday != nil)
        _sundayOpen = State(initialValue: Date.todayAt(minutes: sunday?.opensAt ?? 10 * 60))
        _sundayClose = State(initialValue: Date.todayAt(minutes: sunday?.closesAt ?? 18 * 60))
    }

    var body: some View {
        Form {
            Section("Laden") {
                TextField("Name", text: $draft.name)
                Picker("Kette", selection: $draft.chain) {
                    ForEach(StoreChain.allCases) { chain in
                        Text(chain.displayName).tag(chain)
                    }
                }
                TextField("Adresse oder PLZ", text: $draft.address)
                HStack {
                    Text("Entfernung")
                    Spacer()
                    TextField("km", text: $distanceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 80)
                    Text("km")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("In Berechnung einbeziehen", isOn: $draft.isIncluded)
                Toggle("Bevorzugter Laden", isOn: $draft.isFavorite)
            }

            Section {
                Toggle("Öffnungszeiten hinterlegen", isOn: $hasOpeningHours)
                if hasOpeningHours {
                    DatePicker("Mo–Sa öffnet", selection: $weekdayOpen, displayedComponents: .hourAndMinute)
                    DatePicker("Mo–Sa schließt", selection: $weekdayClose, displayedComponents: .hourAndMinute)
                    Toggle("Sonntags geöffnet", isOn: $openOnSunday)
                    if openOnSunday {
                        DatePicker("So öffnet", selection: $sundayOpen, displayedComponents: .hourAndMinute)
                        DatePicker("So schließt", selection: $sundayClose, displayedComponents: .hourAndMinute)
                    }
                }
            } header: {
                Text("Öffnungszeiten")
            } footer: {
                switch isOpenNow {
                case .some(true): Text("Aktuell geöffnet.")
                case .some(false): Text("Aktuell geschlossen.")
                case .none: Text("Ohne Öffnungszeiten kann nicht geprüft werden, ob der Laden geöffnet ist.")
                }
            }

            Section {
                TextField("Breitengrad, z. B. 51.3127", text: $latitudeText)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Längengrad, z. B. 9.4797", text: $longitudeText)
                    .keyboardType(.numbersAndPunctuation)
            } header: {
                Text("Koordinaten (optional)")
            } footer: {
                Text("Mit Koordinaten aller gewählten Läden wird die Route genauer berechnet. Sonst wird sie aus den Entfernungen geschätzt.")
            }
        }
        .navigationTitle(draft.name.isEmpty ? "Neuer Laden" : draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") {
                    onSave(finalStore())
                    dismiss()
                }
                .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func finalStore() -> Store {
        var store = draft
        store.name = store.name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.distanceKm = DecimalInput.parse(distanceText)
        if let latitude = DecimalInput.parse(latitudeText), let longitude = DecimalInput.parse(longitudeText) {
            store.location = GeoPoint(latitude: latitude, longitude: longitude)
        } else {
            store.location = nil
        }
        if hasOpeningHours {
            var periods = (2...7).map {
                OpeningPeriod(weekday: $0, opensAt: weekdayOpen.minutesSinceMidnight, closesAt: weekdayClose.minutesSinceMidnight)
            }
            if openOnSunday {
                periods.append(OpeningPeriod(weekday: 1, opensAt: sundayOpen.minutesSinceMidnight, closesAt: sundayClose.minutesSinceMidnight))
            }
            store.openingHours = periods
        } else {
            store.openingHours = []
        }
        return store
    }
}
