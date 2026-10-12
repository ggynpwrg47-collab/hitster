import SwiftUI
import SparListeCore
import SparListeFeatures

@main
struct SparListeApp: App {
    /// Wird genau einmal beim Start aufgebaut: lokale JSON-Datei im Application-Support-Verzeichnis.
    private let startup = AppStartup.make()

    var body: some Scene {
        WindowGroup {
            switch startup {
            case let .ready(dependencies):
                RootView(dependencies: dependencies)
            case let .failed(message):
                StartupErrorView(message: message)
            }
        }
    }
}

enum AppStartup {
    case ready(AppDependencies)
    case failed(String)

    static func make() -> AppStartup {
        do {
            let persistence = try JSONFilePersistence.defaultLocation()
            let store = try LocalDataStore(persistence: persistence)
            return .ready(.local(store))
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

struct StartupErrorView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Daten konnten nicht geladen werden", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Die lokale Datendatei ist nicht lesbar. Details: \(message)")
        }
    }
}
