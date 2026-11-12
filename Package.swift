// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Expenses",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // Prodotto principale: l'app.
        .library(name: "Expenses", targets: ["Expenses"]),
        // Estensione widget, collegata in xtool.yml sotto `extensions`.
        .library(name: "ExpensesWidget", targets: ["ExpensesWidget"]),
    ],
    dependencies: [
        .package(path: "ExpensesCore"),
    ],
    targets: [
        .target(
            name: "Expenses",
            dependencies: [.product(name: "ExpensesCore", package: "ExpensesCore")]
        ),
        .target(
            name: "ExpensesWidget",
            dependencies: [.product(name: "ExpensesCore", package: "ExpensesCore")],
            // Swift 6.4: il linker usa -e _NSExtensionMain e -dead_strip e scarta _main
            // (e con lui tutto il codice del widget). Lo teniamo esplicitamente.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-u", "-Xlinker", "_main"])]
        ),
    ]
)
