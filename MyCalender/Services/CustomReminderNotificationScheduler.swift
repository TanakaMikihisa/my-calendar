import Foundation
import UserNotifications

/// ユーザー指定の日時で単発通知を登録する。
struct CustomReminderNotificationScheduler {
    enum SchedulerError: LocalizedError {
        case unauthorized
        /// 登録日時が現在時刻以下（遅延が 0 以下）のとき。編集直後の時計ズレ等で稀に起こり得る。
        case fireDateNotInFuture

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "通知が許可されていません。設定アプリで通知を許可してください。"
            case .fireDateNotInFuture:
                return "通知日時を現在より後に設定してください。"
            }
        }
    }

    static let shared = CustomReminderNotificationScheduler()

    private init() {}

    static func notificationIdentifier(for rapidEventId: RapidEventID) -> String {
        "customReminder.\(rapidEventId)"
    }

    /// 指定の **絶対時刻** に 1 回だけ発火する保留通知に差し替える。編集を繰り返しても同じ `identifier` で上書きされる。
    /// カレンダー成分に秒を捨てる方式だと、DatePicker の時刻とズレたり、直近の枠で予約に失敗することがあるため `timeInterval` で登録する。
    func schedule(
        at date: Date,
        title: String,
        body: String,
        identifier: String
    ) async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { throw SchedulerError.unauthorized }

        let delay = date.timeIntervalSinceNow
        guard delay > 0 else { throw SchedulerError.fireDateNotInFuture }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
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
