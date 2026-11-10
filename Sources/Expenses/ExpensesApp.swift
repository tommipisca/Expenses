import SwiftUI
import UIKit
import ExpensesCore

@main
struct ExpensesApp: App {
    @State private var store = ExpenseStore(fileURL: AppGroup.dataFileURL())
    @State private var router = AppRouter()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.surface)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onOpenURL { router.handle($0) }
        }
    }
}
