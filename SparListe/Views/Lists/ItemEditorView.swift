import SwiftUI
import SparListeCore

/// Details eines Listeneintrags: Menge, Packungsgröße, Marke, Vorlieben, Ausschlüsse.
@MainActor
struct ItemEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let brandsProvider: (String) -> [Brand]
    let onSave: (ShoppingListItem) -> Void
    let onDelete: () -> Void

    @State private var draft: ShoppingListItem
    @State private var hasPackageSize: Bool
    @State private var sizeText: String
    @State private var sizeUnit: MeasureUnit
    @State private var ingredientsText: String

    init(
        item: ShoppingListItem,
        brandsProvider: @escaping (String) -> [Brand],
        onSave: @escaping (ShoppingListItem) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.brandsProvider = brandsProvider
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: item)
        _hasPackageSize = State(initialValue: item.desiredPackageSize != nil)
        _sizeText = State(initialValue: DecimalInput.format(item.desiredPackageSize?.value ?? 1))
        _sizeUnit = State(initialValue: item.desiredPackageSize?.unit ?? .piece)
        _ingredientsText = State(initialValue: item.excludedIngredients.joined(separator: ", "))
    }

    private var brands: [Brand] { brandsProvider(draft.query) }

    var body: some View {
        Form {
            Section("Produkt") {
                TextField("Produkt, z. B. Laktosefreie Milch", text: $draft.query)
                    .autocorrectionDisabled()
                Stepper("Menge: \(draft.quantity)", value: $draft.quantity, in: 1...99)
            }

            Section {
                Toggle("Gewünschte Packungsgröße", isOn: $hasPackageSize)
                if hasPackageSize {
                    HStack {
                        TextField("Größe", text: $sizeText)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 90)
                        Picker("Einheit", selection: $sizeUnit) {
                            ForEach(MeasureUnit.allCases, id: \.self) { unit in
                                Text(unit.symbol).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            } header: {
                Text("Packungsgröße")
            } footer: {
                Text(hasPackageSize
                     ? "Bedarf = Menge × Packungsgröße. Andere Packungsgrößen werden über den Einheitspreis vergleichbar gemacht."
                     : "Ohne Angabe gilt die häufigste Packungsgröße des Produkts; Menge = Anzahl Packungen.")
            }

            Section {
                Picker("Marke", selection: $draft.requiredBrandID) {
                    Text("Beliebige Marke").tag(String?.none)
                    ForEach(brands) { brand in
                        Text(brand.isPrivateLabel ? "\(brand.name) (Eigenmarke)" : brand.name)
                            .tag(Optional(brand.id))
                    }
                }
                if draft.requiredBrandID != nil {
                    Toggle("Alternative einplanen, falls nicht verfügbar", isOn: $draft.allowsBrandSubstitution)
                }
            } header: {
                Text("Marke")
            } footer: {
                Text("Eine Wunschmarke hat Vorrang vor dem günstigsten Preis. Ist sie nirgends verfügbar, wird das deutlich angezeigt und es werden Alternativen vorgeschlagen.")
            }

            Section("Vorlieben") {
                Toggle("Bio-Produkt bevorzugt", isOn: $draft.prefersOrganic)
                Toggle("Eigenmarke bevorzugt", isOn: $draft.prefersPrivateLabel)
            }

            Section {
                DisclosureGroup("Ausgeschlossene Marken (\(draft.excludedBrandIDs.count))") {
                    ForEach(brands) { brand in
                        Button {
                            toggleExcluded(brand.id)
                        } label: {
                            HStack {
                                Text(brand.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if draft.excludedBrandIDs.contains(brand.id) {
                                    Image(systemName: "nosign")
                                        .foregroundStyle(Color.red)
                                }
                            }
                        }
                    }
                }
                TextField("Zutaten ausschließen, z. B. Palmöl, Gluten", text: $ingredientsText)
                    .autocorrectionDisabled()
            } header: {
                Text("Ausschlüsse")
            } footer: {
                Text("Mehrere Zutaten durch Komma trennen.")
            }

            Section("Notiz") {
                TextField("Optional", text: $draft.note, axis: .vertical)
            }

            Section {
                Button("Produkt aus Liste entfernen", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            }
        }
        .navigationTitle("Produkt bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") {
                    onSave(finalItem())
                    dismiss()
                }
                .disabled(draft.query.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func toggleExcluded(_ brandID: String) {
        if let index = draft.excludedBrandIDs.firstIndex(of: brandID) {
            draft.excludedBrandIDs.remove(at: index)
        } else {
            draft.excludedBrandIDs.append(brandID)
        }
    }

    private func finalItem() -> ShoppingListItem {
        var item = draft
        item.query = item.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasPackageSize, let value = DecimalInput.parse(sizeText), value > 0 {
            item.desiredPackageSize = Quantity(value, sizeUnit)
        } else {
            item.desiredPackageSize = nil
        }
        if item.requiredBrandID == nil {
            item.allowsBrandSubstitution = false
        }
        item.excludedIngredients = ingredientsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return item
    }
}
