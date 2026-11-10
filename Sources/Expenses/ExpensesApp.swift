import SwiftUI
import ExpensesCore

@main
struct ExpensesApp: App {
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color(red: 0x0E / 255, green: 0x11 / 255, blue: 0x17 / 255).ignoresSafeArea()
                Text("Expenses").foregroundStyle(.white)
            }
            .preferredColorScheme(.dark)
        }
    }
}
