import Foundation
import Observation

@Observable
@MainActor
final class CreateReminderNotificationViewModel {
    private let tagRepository: TagRepositoryProtocol
    private let rapidEventRepository: RapidEventRepositoryProtocol
    private let eventRepository: EventRepositoryProtocol
    private let scheduler: CustomReminderNotificationScheduler

    var notifyAt: Date
    var title: String = ""
    var body: String = ""
    var tags: [Tag] = []
    var selectedTagId: TagID?
    var shouldAlsoAddToSchedule = false
    var pendingRapidEvents: [RapidEvent] = []
    var isLoadingPendingRapidEvents = false

    var isSaving = false
    var errorMessage: String?

    init(
        defaultDate: Date,
        tagRepository: TagRepositoryProtocol? = nil,
        rapidEventRepository: RapidEventRepositoryProtocol? = nil,
        eventRepository: EventRepositoryProtocol? = nil,
        scheduler: CustomReminderNotificationScheduler? = nil
    ) {
        let now = Date()
        if defaultDate > now {
            self.notifyAt = defaultDate
        } else {
            self.notifyAt = now.addingTimeInterval(600)
        }
        self.tagRepository = tagRepository ?? FirestoreTagRepository()
        self.rapidEventRepository = rapidEventRepository ?? FirestoreRapidEventRepository()
        self.eventRepository = eventRepository ?? FirestoreEventRepository()
        self.scheduler = scheduler ?? .shared
    }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && notifyAt > Date()
    }

    var selectedTagName: String? {
        guard let selectedTagId else { return nil }
        return tags.first(where: { $0.id == selectedTagId })?.name
    }

    /// rapidEventはタグ1件のみ許可。未選択または一覧外IDはnilとして扱う。
    private var normalizedSelectedTagId: TagID? {
        guard let selectedTagId else { return nil }
        return tags.contains(where: { $0.id == selectedTagId }) ? selectedTagId : nil
    }

    func loadTags() {
        Task {
            do {
                tags = try await tagRepository.listActive()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func saveReminder() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        defer { isSaving = false }

        do {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            let now = Date()
            let rapidEvent = RapidEvent(
                id: UUID().uuidString,
                notifyAt: notifyAt,
                title: trimmedTitle,
                body: trimmedBody,
                tagId: normalizedSelectedTagId,
                isNotified: false,
                isActive: true,
                createdAt: now,
                updatedAt: now
            )
            try await rapidEventRepository.upsert(rapidEvent: rapidEvent)

            if shouldAlsoAddToSchedule {
                let event = Event(
                    id: UUID().uuidString,
                    type: .normal,
                    title: trimmedTitle,
                    startAt: notifyAt,
                    endAt: notifyAt.addingTimeInterval(3600),
                    note: trimmedBody,
                    tagIds: normalizedSelectedTagId.map { [$0] } ?? [],
                    isActive: true,
                    createdAt: now,
                    updatedAt: now
                )
                try await eventRepository.upsert(event: event)
            }

            try await scheduler.schedule(
                at: notifyAt,
                title: trimmedTitle,
                body: trimmedBody,
                identifier: CustomReminderNotificationScheduler.notificationIdentifier(for: rapidEvent.id)
            )
            try await loadPendingRapidEvents()
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func loadPendingRapidEvents() async throws {
        isLoadingPendingRapidEvents = true
        defer { isLoadingPendingRapidEvents = false }
        pendingRapidEvents = try await rapidEventRepository.listPending()
    }

    func updatePendingRapidEvent(
        _ rapidEvent: RapidEvent,
        notifyAt: Date,
        title: String,
        body: String,
        selectedTagId: TagID?
    ) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, notifyAt > Date() else { return false }
        let normalizedTagId = tags.contains(where: { $0.id == selectedTagId }) ? selectedTagId : nil
        do {
            let updated = RapidEvent(
                id: rapidEvent.id,
                notifyAt: notifyAt,
                title: trimmedTitle,
                body: trimmedBody,
                tagId: normalizedTagId,
                isNotified: false,
                isActive: rapidEvent.isActive,
                createdAt: rapidEvent.createdAt,
                updatedAt: Date()
            )
            try await rapidEventRepository.upsert(rapidEvent: updated)
            try await scheduler.schedule(
                at: notifyAt,
                title: trimmedTitle,
                body: trimmedBody,
                identifier: CustomReminderNotificationScheduler.notificationIdentifier(for: rapidEvent.id)
            )
            try await loadPendingRapidEvents()
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deletePendingRapidEvent(_ rapidEvent: RapidEvent) async {
        do {
            try await rapidEventRepository.deactivate(rapidEventId: rapidEvent.id)
            scheduler.removePendingNotification(
                identifier: CustomReminderNotificationScheduler.notificationIdentifier(for: rapidEvent.id)
            )
            try await loadPendingRapidEvents()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
