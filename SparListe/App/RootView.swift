import SwiftUI
import SparListeFeatures

/// Hauptnavigation: Listen, Läden & Einstellungen, Produkte & Preise.
@MainActor
struct RootView: View {
    let dependencies: AppDependencies

    var body: some View {
        TabView {
            ListsOverviewView(dependencies: dependencies)
                .tabItem { Label("Listen", systemImage: "list.bullet.clipboard") }

            StoresView(dependencies: dependencies)
                .tabItem { Label("Läden", systemImage: "storefront") }

            CatalogView(dependencies: dependencies)
                .tabItem { Label("Preise", systemImage: "tag") }
        }
    }
}

#Preview {
    RootView(dependencies: .preview())
}
