import Foundation

/// 起動時に未通知の RapidEvent を読み込み、ローカル通知を再スケジュールする。
actor RapidEventNotificationBootstrapper {
    static let shared = RapidEventNotificationBootstrapper()

    private let rapidEventRepository: RapidEventRepositoryProtocol
    private let scheduler: CustomReminderNotificationScheduler

    init(
        rapidEventRepository: RapidEventRepositoryProtocol = FirestoreRapidEventRepository(),
        scheduler: CustomReminderNotificationScheduler = .shared
    ) {
        self.rapidEventRepository = rapidEventRepository
        self.scheduler = scheduler
    }

    func restorePendingNotificationsAtLaunch() async {
        do {
            let pendingRapidEvents = try await rapidEventRepository.listPending()
            for item in pendingRapidEvents {
                try await scheduler.schedule(
                    at: item.notifyAt,
                    title: item.title,
                    body: item.body,
                    identifier: CustomReminderNotificationScheduler.notificationIdentifier(for: item.id)
                )
            }
        } catch {
            // 起動継続を優先。必要なら呼び出し元で監視する。
        }
    }
}
