import Foundation
import UserNotifications
import ExpensesCore

/// Avvisi di budget: notifiche locali all'80% e al 100%, una sola volta per budget e per mese
/// (lo stato degli avvisi inviati è sincronizzato, così iPhone e iPad non avvisano due volte).
@MainActor
@Observable
final class BudgetNotifier {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func evaluate(store: ExpenseStore) async {
        let month = store.currentMonth
        let statuses = store.budgetStatuses(for: month)
        let pending = pendingAlerts(statuses: statuses, month: month, alreadySent: store.data.sentAlerts)
        guard !pending.isEmpty else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        for key in pending {
            guard let status = statuses.first(where: { $0.target == key.target }) else { continue }
            let content = UNMutableNotificationContent()
            let name: String = switch key.target {
            case .total: "mensile"
            case .tag(let id): "«\(store.tag(id: id)?.name ?? "tag")»"
            }
            content.title = key.threshold == .hundred ? "Budget \(name) superato" : "Budget \(name) all'80%"
            content.body = "Hai speso \(Money.format(status.spentCents)) di \(Money.format(status.limitCents)) a \(Formatting.monthName(month))."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "budget-\(key.id)", content: content, trigger: nil)
            try? await center.add(request)
        }
        store.markAlertsSent(pending)
    }
}
