import SwiftUI
import SparListeCore
import SparListeFeatures

/// Startbildschirm mit allen gespeicherten Einkaufslisten.
@MainActor
struct ListsOverviewView: View {
    let dependencies: AppDependencies
    @State private var viewModel: ListsOverviewViewModel
    @State private var path: [UUID] = []
    @State private var isCreating = false
    @State private var newListName = ""
    @State private var renamingList: ShoppingList?
    @State private var renameText = ""

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: ListsOverviewViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Einkaufslisten")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            newListName = ""
                            isCreating = true
                        } label: {
                            Label("Neue Liste", systemImage: "plus")
                        }
                    }
                }
                .navigationDestination(for: UUID.self) { listID in
                    ListEditorView(listID: listID, dependencies: dependencies)
                }
                .alert("Neue Einkaufsliste", isPresented: $isCreating) {
                    TextField("Name, z. B. Wocheneinkauf", text: $newListName)
                    Button("Abbrechen", role: .cancel) {}
                    Button("Anlegen") {
                        Task {
                            if let list = await viewModel.createList(named: newListName) {
                                path.append(list.id)
                            }
                        }
                    }
                }
                .alert("Liste umbenennen", isPresented: Binding(
                    get: { renamingList != nil },
                    set: { if !$0 { renamingList = nil } }
                )) {
                    TextField("Name", text: $renameText)
                    Button("Abbrechen", role: .cancel) {}
                    Button("Speichern") {
                        if let list = renamingList {
                            Task { await viewModel.rename(list, to: renameText) }
                        }
                    }
                }
                .errorAlert($viewModel.actionError)
                .onAppear {
                    Task { await viewModel.load() }
                }
                .refreshable {
                    await viewModel.load()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingStateView(text: "Lade Listen …")
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await viewModel.load() }
            }
        case .loaded:
            if viewModel.lists.isEmpty {
                ContentUnavailableView {
                    Label("Noch keine Einkaufslisten", systemImage: "cart")
                } description: {
                    Text("Lege eine Liste an, füge Produkte hinzu und lass dir die günstigste Aufteilung auf deine Läden berechnen.")
                } actions: {
                    Button("Neue Liste anlegen") {
                        newListName = ""
                        isCreating = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(viewModel.lists) { list in
                        NavigationLink(value: list.id) {
                            ListRow(list: list)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.delete(list) }
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await viewModel.duplicate(list) }
                            } label: {
                                Label("Duplizieren", systemImage: "plus.square.on.square")
                            }
                            .tint(.blue)
                        }
                        .contextMenu {
                            Button {
                                Task { await viewModel.duplicate(list) }
                            } label: {
                                Label("Duplizieren & wiederverwenden", systemImage: "plus.square.on.square")
                            }
                            Button {
                                renameText = list.name
                                renamingList = list
                            } label: {
                                Label("Umbenennen", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                Task { await viewModel.delete(list) }
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ListRow: View {
    let list: ShoppingList

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(list.name)
                .font(.headline)
            HStack {
                Text(ListsOverviewViewModel.progressText(for: list))
                Spacer()
                Text(list.updatedAt, format: .dateTime.day().month().hour().minute())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
