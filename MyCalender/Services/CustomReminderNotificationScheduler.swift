import Foundation
import UserNotifications

/// ユーザー指定の日時で単発通知を登録する。
struct CustomReminderNotificationScheduler {
    enum SchedulerError: LocalizedError {
        case unauthorized

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "通知が許可されていません。設定アプリで通知を許可してください。"
            }
        }
    }

    static let shared = CustomReminderNotificationScheduler()

    private init() {}

    static func notificationIdentifier(for rapidEventId: RapidEventID) -> String {
        "customReminder.\(rapidEventId)"
    }

    func schedule(
        at date: Date,
        title: String,
        body: String,
        identifier: String
    ) async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { throw SchedulerError.unauthorized }

        let calendar = Calendar.current
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        components.second = 0

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    func removePendingNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
