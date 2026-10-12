import SwiftUI
import SparListeCore
import SparListeFeatures

/// Produkt anlegen oder bearbeiten.
@MainActor
struct ProductEditorView: View {
    let viewModel: CatalogViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Product
    @State private var sizeText: String
    @State private var ingredientsText: String
    @State private var keywordsText: String
    @State private var newBrandName = ""
    @State private var newBrandChain: StoreChain?

    init(product: Product, viewModel: CatalogViewModel) {
        self.viewModel = viewModel
        _draft = State(initialValue: product)
        _sizeText = State(initialValue: DecimalInput.format(product.packageSize.value))
        _ingredientsText = State(initialValue: product.ingredients.joined(separator: ", "))
        _keywordsText = State(initialValue: product.keywords.joined(separator: ", "))
    }

    private var sortedBrands: [Brand] {
        viewModel.catalog.brands.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Form {
            Section {
                TextField("Artikelname, z. B. Ja! Laktosefreie Milch 1,5 %", text: $draft.name)
                TextField("Allgemeiner Name, z. B. Laktosefreie Milch", text: $draft.genericName)
                TextField("Kategorie", text: $draft.category)
            } header: {
                Text("Produkt")
            } footer: {
                Text("Über den allgemeinen Namen werden Listeneinträge diesem Produkt zugeordnet.")
            }

            Section("Packung") {
                HStack {
                    TextField("Größe", text: $sizeText)
                        .keyboardType(.decimalPad)
                        .frame(maxWidth: 90)
                    Picker("Einheit", selection: $draft.packageSize.unit) {
                        ForEach(MeasureUnit.allCases, id: \.self) { unit in
                            Text(unit.symbol).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Toggle("Bio-Produkt", isOn: $draft.isOrganic)
            }

            Section("Marke") {
                Picker("Marke", selection: $draft.brandID) {
                    Text("Ohne Marke").tag(String?.none)
                    ForEach(sortedBrands) { brand in
                        Text(brand.isPrivateLabel ? "\(brand.name) (Eigenmarke)" : brand.name)
                            .tag(Optional(brand.id))
                    }
                }
                DisclosureGroup("Neue Marke anlegen") {
                    TextField("Markenname", text: $newBrandName)
                    Picker("Art", selection: $newBrandChain) {
                        Text("Herstellermarke").tag(StoreChain?.none)
                        ForEach(StoreChain.allCases) { chain in
                            Text("Eigenmarke von \(chain.displayName)").tag(Optional(chain))
                        }
                    }
                    Button("Marke anlegen und auswählen") {
                        Task {
                            if let brand = await viewModel.brand(named: newBrandName, privateLabelOf: newBrandChain) {
                                draft.brandID = brand.id
                                newBrandName = ""
                            }
                        }
                    }
                    .disabled(newBrandName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section {
                TextField("Zutaten/Merkmale, kommagetrennt", text: $ingredientsText)
                TextField("Suchbegriffe, kommagetrennt", text: $keywordsText)
            } header: {
                Text("Details")
            } footer: {
                Text("Zutaten werden für Ausschlüsse genutzt (z. B. „Palmöl“), Suchbegriffe für Zuordnung und Vorschläge.")
            }
        }
        .navigationTitle(draft.name.isEmpty ? "Neues Produkt" : "Produkt bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") {
                    let product = finalProduct()
                    Task { await viewModel.save(product) }
                    dismiss()
                }
                .disabled(!isValid)
            }
        }
    }

    private var isValid: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !draft.genericName.trimmingCharacters(in: .whitespaces).isEmpty
            && (DecimalInput.parse(sizeText) ?? 0) > 0
    }

    private func finalProduct() -> Product {
        var product = draft
        product.name = product.name.trimmingCharacters(in: .whitespacesAndNewlines)
        product.genericName = product.genericName.trimmingCharacters(in: .whitespacesAndNewlines)
        product.packageSize.value = DecimalInput.parse(sizeText) ?? 1
        product.ingredients = Self.splitList(ingredientsText)
        product.keywords = Self.splitList(keywordsText)
        if product.category.trimmingCharacters(in: .whitespaces).isEmpty {
            product.category = "Sonstiges"
        }
        return product
    }

    static func splitList(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

/// Preis oder Angebot erfassen bzw. bearbeiten.
@MainActor
struct PriceEditorView: View {
    let stores: [Store]
    let onSave: (PriceEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var draft: PriceEntry
    @State private var priceText: String
    @State private var isOffer: Bool
    @State private var validFrom: Date
    @State private var validUntil: Date

    init(entry: PriceEntry, stores: [Store], onSave: @escaping (PriceEntry) -> Void) {
        self.stores = stores
        self.onSave = onSave
        _draft = State(initialValue: entry)
        _priceText = State(initialValue: entry.price.cents == 0 ? "" : DecimalInput.format(entry.price.euros))
        switch entry.kind {
        case .regular:
            _isOffer = State(initialValue: false)
            _validFrom = State(initialValue: Date())
            _validUntil = State(initialValue: Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date())
        case let .offer(from, until):
            _isOffer = State(initialValue: true)
            _validFrom = State(initialValue: from)
            _validUntil = State(initialValue: until)
        }
    }

    var body: some View {
        Form {
            Section("Preis") {
                Picker("Laden", selection: $draft.storeID) {
                    ForEach(stores) { store in
                        Text(store.name).tag(store.id)
                    }
                }
                HStack {
                    Text("Preis")
                    Spacer()
                    TextField("0,00", text: $priceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text("€")
                        .foregroundStyle(.secondary)
                }
                Picker("Verfügbarkeit", selection: $draft.availability) {
                    ForEach(Availability.allCases, id: \.self) { availability in
                        Text(availability.displayName).tag(availability)
                    }
                }
            }

            Section {
                Toggle("Aktionspreis (Angebot)", isOn: $isOffer)
                if isOffer {
                    DatePicker("Gültig ab", selection: $validFrom, displayedComponents: .date)
                    DatePicker("Gültig bis", selection: $validUntil, displayedComponents: .date)
                }
            } header: {
                Text("Angebot")
            } footer: {
                Text("Ein Angebot geht nur in die Berechnung ein, solange es gültig ist (vom ersten bis einschließlich letzten Tag).")
            }

            Section("Herkunft") {
                Picker("Quelle", selection: $draft.source) {
                    ForEach(PriceSource.allCases, id: \.self) { source in
                        Text(source.displayName).tag(source)
                    }
                }
                DatePicker("Erfasst am", selection: $draft.observedAt, displayedComponents: .date)
            }
        }
        .navigationTitle("Preis erfassen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Sichern") {
                    onSave(finalEntry())
                    dismiss()
                }
                .disabled(DecimalInput.parse(priceText) == nil || draft.storeID.isEmpty)
            }
        }
    }

    private func finalEntry() -> PriceEntry {
        var entry = draft
        entry.price = Money(euros: DecimalInput.parse(priceText) ?? 0)
        // Ein Enddatum vor dem Beginn wird auf den Beginn gesetzt.
        entry.kind = isOffer ? .offer(validFrom: validFrom, validUntil: max(validFrom, validUntil)) : .regular
        return entry
    }
}
