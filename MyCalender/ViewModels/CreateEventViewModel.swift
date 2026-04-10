import Foundation
import Observation

@Observable
final class CreateEventViewModel {
    private let authRepository: AuthRepositoryProtocol
    private let eventRepository: EventRepositoryProtocol
    private let tagRepository: TagRepositoryProtocol
    private let eventTemplateRepository: EventTemplateRepositoryProtocol

    var title: String = ""
    var startAt: Date
    var endAt: Date
    var note: String = ""
    var tags: [Tag] = []
    var selectedTagIds: Set<TagID> = []
    var eventTemplates: [EventTemplate] = []
    var selectedEventTemplateId: EventTemplateID = ""

    var isSaving: Bool = false
    var errorMessage: String?

    init(
        initialDate: Date,
        authRepository: AuthRepositoryProtocol = FirebaseAuthRepository(),
        eventRepository: EventRepositoryProtocol = FirestoreEventRepository(),
        tagRepository: TagRepositoryProtocol = FirestoreTagRepository(),
        eventTemplateRepository: EventTemplateRepositoryProtocol = FirestoreEventTemplateRepository()
    ) {
        self.authRepository = authRepository
        self.eventRepository = eventRepository
        self.tagRepository = tagRepository
        self.eventTemplateRepository = eventTemplateRepository
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate) ?? initialDate
        let end = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: initialDate) ?? initialDate.addingTimeInterval(3600)
        self.startAt = start
        self.endAt = end
    }

    func loadTags() {
        Task { @MainActor in
            do {
                tags = try await tagRepository.listActive()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadEventTemplates() {
        Task { @MainActor in
            do {
                eventTemplates = try await eventTemplateRepository.listActive()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggleTag(_ id: TagID) {
        if selectedTagIds.contains(id) {
            selectedTagIds.remove(id)
        } else {
            selectedTagIds = [id]
        }
    }

    private var singleSelectedTagIds: [TagID] {
        guard let first = selectedTagIds.first else { return [] }
        return [first]
    }

    var canSave: Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && startAt < endAt
    }

    /// タイトルに "H:mm-H:mm" または "H:mm〜H:mm" があれば開始・終了をその値に更新する
    func applyTimeRangeFromTitleIfNeeded() {
        guard let range = title.parsedTimeRange() else { return }
        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: startAt)
        guard let newStart = calendar.date(bySettingHour: range.startHour, minute: range.startMinute, second: 0, of: baseDate),
              var newEnd = calendar.date(bySettingHour: range.endHour, minute: range.endMinute, second: 0, of: baseDate) else { return }
        if newEnd <= newStart {
            newEnd = calendar.date(byAdding: .day, value: 1, to: newEnd) ?? newEnd
        }
        startAt = newStart
        endAt = newEnd
    }

    /// 開始変更で終了が開始以下になった場合、終了を開始+1時間に補正する
    func normalizeEndAtAfterStartChanged() {
        guard endAt <= startAt else { return }
        endAt = startAt.addingTimeInterval(3600)
    }

    func save() async -> Bool {
        guard canSave else { return false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        await MainActor.run { isSaving = true }
        defer { Task { @MainActor in isSaving = false } }

        do {
            let now = Date()
            let event = Event(
                id: UUID().uuidString,
                type: .normal,
                title: trimmedTitle,
                startAt: startAt,
                endAt: endAt,
                note: note.isEmpty ? nil : note,
                tagIds: singleSelectedTagIds,
                isActive: true,
                createdAt: now,
                updatedAt: now
            )
            try await eventRepository.upsert(event: event)
            await MainActor.run { errorMessage = nil }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func saveAsTemplate() async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, startAt < endAt else { return false }
        do {
            let calendar = Calendar.current
            let template = EventTemplate(
                id: UUID().uuidString,
                title: trimmedTitle,
                note: note.isEmpty ? nil : note,
                startTime: startAt.toTimeString(calendar: calendar),
                endTime: endAt.toTimeString(calendar: calendar),
                tagIds: singleSelectedTagIds,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await eventTemplateRepository.add(template: template)
            await MainActor.run {
                selectedEventTemplateId = template.id
                loadEventTemplates()
            }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func applyEventTemplate(id: EventTemplateID) {
        guard let template = eventTemplates.first(where: { $0.id == id }) else { return }
        selectedEventTemplateId = id
        title = template.title
        note = template.note ?? ""
        if let first = template.tagIds.first {
            selectedTagIds = [first]
        } else {
            selectedTagIds = []
        }

        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: startAt)
        let parsedStart = Date.fromTimeString(template.startTime)
        let parsedEnd = Date.fromTimeString(template.endTime)
        let startHour = parsedStart.map { calendar.component(.hour, from: $0) } ?? 9
        let startMinute = parsedStart.map { calendar.component(.minute, from: $0) } ?? 0
        let endHour = parsedEnd.map { calendar.component(.hour, from: $0) } ?? 10
        let endMinute = parsedEnd.map { calendar.component(.minute, from: $0) } ?? 0

        guard let newStart = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: baseDate),
              var newEnd = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: baseDate) else { return }
        if newEnd <= newStart {
            newEnd = calendar.date(byAdding: .day, value: 1, to: newEnd) ?? newEnd
        }
        startAt = newStart
        endAt = newEnd
    }

    func save(onDates: [Date]) async -> Bool {
        let normalizedDates = Array(Set(onDates.map { $0.startOfDay() })).sorted()
        guard !normalizedDates.isEmpty else { return await save() }
        guard canSave else { return false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = Calendar.current

        await MainActor.run { isSaving = true }
        defer { Task { @MainActor in isSaving = false } }

        do {
            let now = Date()

            let baseStartHour = calendar.component(.hour, from: startAt)
            let baseStartMinute = calendar.component(.minute, from: startAt)
            let baseEndHour = calendar.component(.hour, from: endAt)
            let baseEndMinute = calendar.component(.minute, from: endAt)
            let wrapsToNextDay = endAt <= startAt

            for date in normalizedDates {
                guard let start = calendar.date(bySettingHour: baseStartHour, minute: baseStartMinute, second: 0, of: date),
                      var end = calendar.date(bySettingHour: baseEndHour, minute: baseEndMinute, second: 0, of: date)
                else { continue }
                if wrapsToNextDay || end <= start {
                    end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
                }

                let event = Event(
                    id: UUID().uuidString,
                    type: .normal,
                    title: trimmedTitle,
                    startAt: start,
                    endAt: end,
                    note: note.isEmpty ? nil : note,
                    tagIds: singleSelectedTagIds,
                    isActive: true,
                    createdAt: now,
                    updatedAt: now
                )
                try await eventRepository.upsert(event: event)
            }

            await MainActor.run { errorMessage = nil }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }
}
