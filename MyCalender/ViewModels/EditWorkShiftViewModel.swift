import Foundation
import Observation

@Observable
final class EditWorkShiftViewModel {
    private let authRepository: AuthRepositoryProtocol
    private let workShiftRepository: WorkShiftRepositoryProtocol
    private let tagRepository: TagRepositoryProtocol
    private let payRateRepository: PayRateRepositoryProtocol
    private let hourlyRateRepository: HourlyRateRepositoryProtocol

    let shiftId: String
    var startAt: Date
    var endAt: Date
    /// 休憩時間（分）の入力用文字列。任意。デフォルト "0"。
    var breakMinutesText: String
    var payType: WorkPayType
    var fixedPayText: String
    /// 固定給のときの会社名（入力用）
    var companyNameText: String
    var selectedPayRateId: PayRateID?
    var selectedHourlyRateId: HourlyRateID?
    var payRates: [PayRate] = []
    var hourlyRates: [HourlyRate] = []
    var tags: [Tag] = []
    var selectedTagIds: Set<TagID>
    let createdAt: Date

    var isSaving: Bool = false
    var errorMessage: String?

    init(
        shift: WorkShift,
        authRepository: AuthRepositoryProtocol = FirebaseAuthRepository(),
        workShiftRepository: WorkShiftRepositoryProtocol = FirestoreWorkShiftRepository(),
        tagRepository: TagRepositoryProtocol = FirestoreTagRepository(),
        payRateRepository: PayRateRepositoryProtocol = FirestorePayRateRepository(),
        hourlyRateRepository: HourlyRateRepositoryProtocol = FirestoreHourlyRateRepository()
    ) {
        self.authRepository = authRepository
        self.workShiftRepository = workShiftRepository
        self.tagRepository = tagRepository
        self.payRateRepository = payRateRepository
        self.hourlyRateRepository = hourlyRateRepository
        self.shiftId = shift.id
        self.startAt = shift.startAt
        self.endAt = shift.endAt
        self.breakMinutesText = shift.breakMinutes > 0 ? "\(shift.breakMinutes)" : ""
        self.payType = shift.payType
        self.fixedPayText = shift.fixedPay.map { "\($0)" } ?? ""
        self.companyNameText = shift.companyName ?? ""
        self.selectedPayRateId = shift.payRateId
        self.selectedHourlyRateId = shift.hourlyRateId
        self.selectedTagIds = Set(shift.tagIds)
        self.createdAt = shift.createdAt
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

    func loadPayRates() {
        Task { @MainActor in
            do {
                payRates = try await payRateRepository.listActive()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadHourlyRates() {
        Task { @MainActor in
            do {
                hourlyRates = try await hourlyRateRepository.listActive()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggleTag(_ id: TagID) {
        if selectedTagIds.contains(id) {
            selectedTagIds.remove(id)
        } else {
            selectedTagIds.insert(id)
        }
    }

    var canSave: Bool {
        guard startAt < endAt else { return false }
        if payType == .fixed {
            return parsedFixedPay != nil
        }
        if payType == .hourly {
            return selectedPayRateId != nil && selectedHourlyRateId != nil
        }
        return true
    }

    var hourlyRatesForSelectedCompany: [HourlyRate] {
        guard let payRateId = selectedPayRateId else { return [] }
        return hourlyRates.filter { $0.payRateId == payRateId }
    }

    private var parsedFixedPay: Decimal? {
        let trimmed = fixedPayText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed)
    }

    /// 休憩時間（分）。未入力・不正値は 0。
    var breakMinutes: Int {
        let trimmed = breakMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let n = Int(trimmed), n >= 0 else { return 0 }
        return n
    }

    func save() async -> Bool {
        guard canSave else { return false }

        await MainActor.run { isSaving = true }
        defer { Task { @MainActor in isSaving = false } }

        do {
            let now = Date()
            let trimmedCompany = companyNameText.trimmingCharacters(in: .whitespacesAndNewlines)
            let companyName: String? = payType == .fixed && !trimmedCompany.isEmpty ? trimmedCompany : nil
            let shift = WorkShift(
                id: shiftId,
                startAt: startAt,
                endAt: endAt,
                breakMinutes: breakMinutes,
                payType: payType,
                payRateId: payType == .hourly ? selectedPayRateId : nil,
                hourlyRateId: payType == .hourly ? selectedHourlyRateId : nil,
                fixedPay: payType == .fixed ? parsedFixedPay : nil,
                companyName: companyName,
                templateId: nil,
                tagIds: Array(selectedTagIds),
                isActive: true,
                createdAt: createdAt,
                updatedAt: now
            )
            try await workShiftRepository.upsert(shift: shift)
            await MainActor.run { errorMessage = nil }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func delete() async -> Bool {
        do {
            try await workShiftRepository.deactivate(shiftId: shiftId)
            await MainActor.run { errorMessage = nil }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }
}
