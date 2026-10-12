import SwiftUI
import UniformTypeIdentifiers
import SparListeCore
import SparListeFeatures

/// Produktkatalog und Preispflege der lokalen Datenquelle.
@MainActor
struct CatalogView: View {
    @State private var viewModel: CatalogViewModel
    @State private var editingProduct: Product?
    @State private var isImporting = false

    init(dependencies: AppDependencies) {
        _viewModel = State(initialValue: CatalogViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Produkte & Preise")
                .searchable(text: $viewModel.searchText, prompt: "Produkt oder Marke suchen")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                editingProduct = viewModel.newProductTemplate()
                            } label: {
                                Label("Produkt anlegen", systemImage: "plus")
                            }
                            if viewModel.canImport {
                                Button {
                                    isImporting = true
                                } label: {
                                    Label("Preise importieren (JSON)", systemImage: "square.and.arrow.down")
                                }
                            }
                        } label: {
                            Label("Hinzufügen", systemImage: "plus")
                        }
                    }
                }
                .sheet(item: $editingProduct) { product in
                    NavigationStack {
                        ProductEditorView(product: product, viewModel: viewModel)
                    }
                }
                .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                    handleImport(result)
                }
                .alert("Import", isPresented: Binding(
                    get: { viewModel.infoMessage != nil },
                    set: { if !$0 { viewModel.infoMessage = nil } }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(viewModel.infoMessage ?? "")
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
            LoadingStateView(text: "Lade Produkte …")
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await viewModel.load() }
            }
        case .loaded:
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Datenquelle: \(viewModel.sourceDescriptor.name)")
                            .font(.subheadline.weight(.semibold))
                        Text(viewModel.sourceDescriptor.limitations)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    SampleDataNotice()
                }

                let groups = viewModel.groupedProducts
                if groups.isEmpty {
                    Section {
                        Text(viewModel.searchText.isEmpty ? "Noch keine Produkte im Katalog." : "Keine Treffer.")
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(groups, id: \.genericName) { group in
                    Section(group.genericName) {
                        ForEach(group.products) { product in
                            NavigationLink {
                                ProductDetailView(productID: product.id, viewModel: viewModel)
                            } label: {
                                ProductRow(
                                    product: product,
                                    brandName: viewModel.brandName(for: product),
                                    priceCount: viewModel.prices(for: product).count
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                Task { await viewModel.importFile(data) }
            } catch {
                viewModel.actionError = "Die Datei konnte nicht gelesen werden: \(error.localizedDescription)"
            }
        case let .failure(error):
            viewModel.actionError = error.localizedDescription
        }
    }
}

private struct ProductRow: View {
    let product: Product
    let brandName: String
    let priceCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(product.name)
            HStack(spacing: 6) {
                Text("\(brandName) · \(product.packageSize.formatted)")
                if product.isOrganic {
                    BadgeView(text: "Bio", color: .green, systemImage: "leaf")
                }
                Spacer()
                Text(priceCount == 1 ? "1 Preis" : "\(priceCount) Preise")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

/// Produktdetails mit allen Preisen und Angeboten.
@MainActor
struct ProductDetailView: View {
    let productID: String
    let viewModel: CatalogViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editingPrice: PriceEntry?
    @State private var editingProduct: Product?
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let product = viewModel.catalog.product(id: productID) {
                list(for: product)
            } else {
                ContentUnavailableView("Produkt nicht gefunden", systemImage: "questionmark.folder")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingPrice) { entry in
            NavigationStack {
                PriceEditorView(entry: entry, stores: viewModel.stores) { updated in
                    Task { await viewModel.save(updated) }
                }
            }
        }
        .sheet(item: $editingProduct) { product in
            NavigationStack {
                ProductEditorView(product: product, viewModel: viewModel)
            }
        }
        .confirmationDialog("Produkt löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let product = viewModel.catalog.product(id: productID) {
                    Task {
                        await viewModel.delete(product)
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Alle Preise dieses Produkts werden ebenfalls gelöscht.")
        }
    }

    private func list(for product: Product) -> some View {
        List {
            Section {
                LabeledContent("Allgemeiner Name", value: product.genericName)
                LabeledContent("Marke", value: viewModel.brandName(for: product))
                LabeledContent("Packungsgröße", value: product.packageSize.formatted)
                LabeledContent("Bio", value: product.isOrganic ? "Ja" : "Nein")
                if !product.ingredients.isEmpty {
                    LabeledContent("Zutaten/Merkmale", value: product.ingredients.joined(separator: ", "))
                }
                LabeledContent("Kategorie", value: product.category)
            }

            Section {
                let entries = viewModel.prices(for: product)
                if entries.isEmpty {
                    Text("Noch keine Preise erfasst.")
                        .foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    PriceRow(
                        entry: entry,
                        product: product,
                        storeName: viewModel.storeName(for: entry.storeID),
                        freshness: viewModel.freshness(of: entry),
                        isValid: viewModel.isValid(entry)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { editingPrice = entry }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await viewModel.delete(entry) }
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
                Button {
                    editingPrice = viewModel.newPriceTemplate(for: product)
                } label: {
                    Label("Preis oder Angebot erfassen", systemImage: "plus")
                }
                .disabled(viewModel.stores.isEmpty)
            } header: {
                Text("Preise & Angebote")
            } footer: {
                Text("Angebote zählen nur innerhalb ihres Gültigkeitszeitraums. Reguläre Preise gelten nach 14 Tagen als veraltet.")
            }
        }
        .navigationTitle(product.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        editingProduct = product
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                } label: {
                    Label("Mehr", systemImage: "ellipsis.circle")
                }
            }
        }
    }
}

private struct PriceRow: View {
    let entry: PriceEntry
    let product: Product
    let storeName: String
    let freshness: PriceFreshness
    let isValid: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(storeName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(entry.price.formatted)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .strikethrough(!isValid)
            }
            HStack(spacing: 4) {
                if let unitPrice = UnitPricing.unitPrice(price: entry.price, packageSize: product.packageSize) {
                    Text(unitPrice.formatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 4) {
                if case let .offer(from, until) = entry.kind {
                    if isValid {
                        OfferBadge(validUntil: until)
                    } else {
                        BadgeView(
                            text: until < Date() ? "Angebot abgelaufen" : "Angebot ab \(DateText.dayMonth(from))",
                            color: .gray
                        )
                    }
                }
                FreshnessBadge(freshness: freshness)
                SourceBadge(source: entry.source)
                if entry.availability != .available {
                    BadgeView(text: entry.availability.displayName, color: entry.availability == .unavailable ? .red : .orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
