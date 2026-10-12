import SwiftUI
import SparListeCore
import SparListeFeatures

/// Einkaufsliste bearbeiten: Produkte hinzufügen (mit Autovervollständigung), abhaken, löschen.
@MainActor
struct ListEditorView: View {
    let dependencies: AppDependencies
    @State private var viewModel: ListEditorViewModel
    @State private var newItemText = ""
    @State private var editingItem: ShoppingListItem?
    @State private var showOptimization = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var addFieldFocused: Bool

    init(listID: UUID, dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: ListEditorViewModel(listID: listID, dependencies: dependencies))
    }

    var body: some View {
        content
            .navigationTitle(viewModel.list?.name ?? "Liste")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            renameText = viewModel.list?.name ?? ""
                            isRenaming = true
                        } label: {
                            Label("Umbenennen", systemImage: "pencil")
                        }
                        Button {
                            Task { await viewModel.uncheckAll() }
                        } label: {
                            Label("Alle Häkchen entfernen", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(viewModel.checkedItems.isEmpty)
                    } label: {
                        Label("Mehr", systemImage: "ellipsis.circle")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.list != nil {
                    Button {
                        addFieldFocused = false
                        showOptimization = true
                    } label: {
                        Label("Günstigste Aufteilung berechnen", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.openItems.isEmpty)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
                }
            }
            .navigationDestination(isPresented: $showOptimization) {
                OptimizationView(listID: viewModel.listID, dependencies: dependencies)
            }
            .sheet(item: $editingItem) { item in
                NavigationStack {
                    ItemEditorView(
                        item: item,
                        brandsProvider: { viewModel.brands(for: $0) },
                        onSave: { updated in Task { await viewModel.update(updated) } },
                        onDelete: { Task { await viewModel.delete(item) } }
                    )
                }
            }
            .alert("Liste umbenennen", isPresented: $isRenaming) {
                TextField("Name", text: $renameText)
                Button("Abbrechen", role: .cancel) {}
                Button("Speichern") {
                    Task { await viewModel.rename(to: renameText) }
                }
            }
            .errorAlert($viewModel.actionError)
            .onAppear {
                Task { await viewModel.load() }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingStateView(text: "Lade Liste …")
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await viewModel.load() }
            }
        case .loaded:
            List {
                addSection

                if viewModel.openItems.isEmpty && viewModel.checkedItems.isEmpty {
                    Section {
                        Text("Noch keine Produkte. Tippe oben einen Produktnamen ein – Vorschläge erscheinen automatisch.")
                            .foregroundStyle(.secondary)
                    }
                }

                if !viewModel.openItems.isEmpty {
                    Section("Einzukaufen (\(viewModel.openItems.count))") {
                        ForEach(viewModel.openItems) { item in
                            itemRow(item)
                        }
                    }
                }

                if !viewModel.checkedItems.isEmpty {
                    Section {
                        ForEach(viewModel.checkedItems) { item in
                            itemRow(item)
                        }
                    } header: {
                        Text("Erledigt (\(viewModel.checkedItems.count))")
                    } footer: {
                        Text("Abgehakte Produkte werden bei der Preisoptimierung nicht berücksichtigt.")
                    }
                }
            }
        }
    }

    private var addSection: some View {
        Section {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.accentColor)
                TextField("Produkt hinzufügen, z. B. Laktosefreie Milch", text: $newItemText)
                    .focused($addFieldFocused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .onSubmit(addFreeText)
            }
            ForEach(viewModel.suggestions(for: newItemText)) { suggestion in
                Button {
                    add(suggestion)
                } label: {
                    HStack {
                        Image(systemName: suggestion.brandID == nil ? "magnifyingglass" : "tag")
                            .foregroundStyle(.secondary)
                        Text(suggestion.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if let size = suggestion.typicalPackageSize {
                            Text(size.formatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } footer: {
            if !newItemText.isEmpty {
                Text("Vorschlag antippen oder mit „Fertig“ als freien Eintrag übernehmen.")
            }
        }
    }

    private func itemRow(_ item: ShoppingListItem) -> some View {
        ItemRow(
            item: item,
            brandName: viewModel.brandName(for: item.requiredBrandID),
            onToggle: { Task { await viewModel.toggleChecked(item) } }
        )
        .contentShape(Rectangle())
        .onTapGesture { editingItem = item }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await viewModel.delete(item) }
            } label: {
                Label("Löschen", systemImage: "trash")
            }
            Button {
                editingItem = item
            } label: {
                Label("Bearbeiten", systemImage: "slider.horizontal.3")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await viewModel.toggleChecked(item) }
            } label: {
                Label(item.isChecked ? "Zurück" : "Erledigt", systemImage: item.isChecked ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(.green)
        }
    }

    private func addFreeText() {
        let text = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        newItemText = ""
        Task { await viewModel.add(ShoppingListItem(query: text)) }
    }

    private func add(_ suggestion: ProductSuggestion) {
        newItemText = ""
        let item = viewModel.makeItem(from: suggestion)
        Task { await viewModel.add(item) }
    }
}

private struct ItemRow: View {
    let item: ShoppingListItem
    let brandName: String?
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isChecked ? Color.green : Color.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(item.isChecked ? "Abhaken rückgängig" : "Abhaken")

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? Color.secondary : Color.primary)
                if !details.isEmpty {
                    Text(details.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private var details: [String] {
        var parts: [String] = []
        if let brandName {
            parts.append(item.allowsBrandSubstitution ? "Marke: \(brandName) (Alternative ok)" : "Marke: \(brandName)")
        }
        if item.prefersOrganic { parts.append("Bio bevorzugt") }
        if item.prefersPrivateLabel { parts.append("Eigenmarke bevorzugt") }
        if !item.excludedBrandIDs.isEmpty { parts.append("\(item.excludedBrandIDs.count) Marke(n) ausgeschlossen") }
        if !item.excludedIngredients.isEmpty { parts.append("ohne \(item.excludedIngredients.joined(separator: ", "))") }
        if !item.note.isEmpty { parts.append(item.note) }
        return parts
    }
}
