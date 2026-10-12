// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SparListeKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SparListeCore", targets: ["SparListeCore"]),
        .library(name: "SparListeFeatures", targets: ["SparListeFeatures"])
    ],
    targets: [
        // Plattformneutrale Domänenlogik: Modelle, Preislogik, Optimierung,
        // Repositories und lokale Persistenz. Nur Foundation, kein UIKit/SwiftUI.
        .target(name: "SparListeCore"),
        // View Models (Observation), unabhängig von SwiftUI und damit testbar.
        .target(name: "SparListeFeatures", dependencies: ["SparListeCore"]),
        .testTarget(name: "SparListeCoreTests", dependencies: ["SparListeCore"]),
        .testTarget(name: "SparListeFeaturesTests", dependencies: ["SparListeFeatures", "SparListeCore"])
    ]
)
