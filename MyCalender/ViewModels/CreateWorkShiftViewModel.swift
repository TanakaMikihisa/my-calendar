import Foundation
import Observation

/// 勤務予定の作成方法
enum WorkShiftCreateMode: String, CaseIterable, Identifiable {
    case fromTemplate = "テンプレから選択"
    case newEntry = "新規作成"
    var id: String { rawValue }
}

@Observable
final class CreateWorkShiftViewModel {
    private let authRepository: AuthRepositoryProtocol
    private let workShiftRepository: WorkShiftRepositoryProtocol
    private let payRateRepository: PayRateRepositoryProtocol
    private let hourlyRateRepository: HourlyRateRepositoryProtocol
    private let shiftTemplateRepository: ShiftTemplateRepositoryProtocol

    /// テンプレから選択 / 新規作成
    var workShiftCreateMode: WorkShiftCreateMode = .fromTemplate
    /// テンプレから選択時に選んだ会社（PayRate）の ID。先に会社を選び、その会社のテンプレのみ表示する。
    var selectedPayRateIdForTemplate: PayRateID?
    /// テンプレから選択時の勤務日（テンプレの開始・終了時刻をこの日に適用）
    var workShiftDate: Date
    /// テンプレから選択時に選んだテンプレート ID
    var selectedTemplateId: ShiftTemplateID?

    var startAt: Date
    var endAt: Date
    var payType: WorkPayType
    /// 固定給のときの金額（入力用文字列）
    var fixedPayText: String = ""
    /// 固定給のときの会社名（入力用）
    var companyNameText: String = ""
    /// 時給のとき選択した会社（PayRate）の ID
    var selectedPayRateId: PayRateID?
    /// 時給のとき選択した時給パターン（HourlyRate）の ID
    var selectedHourlyRateId: HourlyRateID?
    var payRates: [PayRate] = []
    var hourlyRates: [HourlyRate] = []
    var shiftTemplates: [ShiftTemplate] = []

    var isSaving: Bool = false
    var errorMessage: String?

    init(
        initialDate: Date,
        authRepository: AuthRepositoryProtocol = FirebaseAuthRepository(),
        workShiftRepository: WorkShiftRepositoryProtocol = FirestoreWorkShiftRepository(),
        payRateRepository: PayRateRepositoryProtocol = FirestorePayRateRepository(),
        hourlyRateRepository: HourlyRateRepositoryProtocol = FirestoreHourlyRateRepository(),
        shiftTemplateRepository: ShiftTemplateRepositoryProtocol = FirestoreShiftTemplateRepository()
    ) {
        self.authRepository = authRepository
        self.workShiftRepository = workShiftRepository
        self.payRateRepository = payRateRepository
        self.hourlyRateRepository = hourlyRateRepository
        self.shiftTemplateRepository = shiftTemplateRepository
        self.workShiftDate = Calendar.current.startOfDay(for: initialDate)
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate) ?? initialDate
        let end = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: initialDate) ?? start.addingTimeInterval(3600 * 8)
        self.startAt = start
        self.endAt = end
        self.payType = .hourly
    }

    func loadPayRates() {
        Task { @MainActor in
            do {
                let uid = try await authRepository.ensureSignedInAnonymously()
                payRates = try await payRateRepository.listActive(uid: uid)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadHourlyRates() {
        Task { @MainActor in
            do {
                let uid = try await authRepository.ensureSignedInAnonymously()
                hourlyRates = try await hourlyRateRepository.listActive(uid: uid)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadShiftTemplates() {
        Task { @MainActor in
            do {
                let uid = try await authRepository.ensureSignedInAnonymously()
                shiftTemplates = try await shiftTemplateRepository.listActive(uid: uid)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    var canSave: Bool {
        switch workShiftCreateMode {
        case .fromTemplate:
            return selectedPayRateIdForTemplate != nil && selectedTemplateId != nil
        case .newEntry:
            guard startAt < endAt else { return false }
            if payType == .fixed {
                return parsedFixedPay != nil
            }
            if payType == .hourly {
                return selectedPayRateId != nil && selectedHourlyRateId != nil
            }
            return true
        }
    }

    var selectedTemplate: ShiftTemplate? {
        guard let id = selectedTemplateId else { return nil }
        return shiftTemplates.first { $0.id == id }
    }

    func companyTitle(for payRateId: PayRateID) -> String {
        payRates.first { $0.id == payRateId }?.title ?? payRateId
    }

    /// テンプレ一覧の行表示用（会社名: シフト、会社未設定時はシフトのみ）
    func templateDisplayTitle(_ template: ShiftTemplate) -> String {
        let t = companyTitle(for: template.payRateId)
        return t.isEmpty ? template.shiftName : "\(t): \(template.shiftName)"
    }

    /// テンプレから選択で表示する会社一覧（テンプレが1件以上ある会社のみ）
    var payRatesWithTemplates: [PayRate] {
        payRates.filter { rate in shiftTemplates.contains { $0.payRateId == rate.id } }
    }

    /// 選択中の会社に紐づくテンプレート一覧（テンプレから選択時のみ使用）
    var shiftTemplatesForSelectedCompany: [ShiftTemplate] {
        guard let payRateId = selectedPayRateIdForTemplate else { return [] }
        return shiftTemplates.filter { $0.payRateId == payRateId }
    }

    /// テンプレの稼ぎ額（時給なら時間×単価、固定給ならそのまま）。表示用文字列を返す。
    func templateEarningsDisplay(_ template: ShiftTemplate) -> String? {
        let calendar = Calendar.current
        guard let startDate = Date.fromTimeString(template.startTime, calendar: calendar),
              let endDate = Date.fromTimeString(template.endTime, calendar: calendar) else { return nil }
        var durationMinutes = Int(endDate.timeIntervalSince(startDate) / 60)
        if durationMinutes <= 0 { durationMinutes += 24 * 60 }
        let hours = Decimal(durationMinutes) / 60

        switch template.payType {
        case .hourly:
            guard let id = template.hourlyRateId,
                  let rate = hourlyRates.first(where: { $0.id == id }) else { return nil }
            let amount = rate.amount * hours
            return "¥\(NSDecimalNumber(decimal: amount).stringValue)"
        case .fixed:
            guard let fixed = template.fixedPay else { return nil }
            return "¥\(NSDecimalNumber(decimal: fixed).stringValue)"
        }
    }

    var selectedPayRate: PayRate? {
        guard let id = selectedPayRateId else { return nil }
        return payRates.first { $0.id == id }
    }

    /// 選択中の会社に紐づく時給パターン一覧
    var hourlyRatesForSelectedCompany: [HourlyRate] {
        guard let payRateId = selectedPayRateId else { return [] }
        return hourlyRates.filter { $0.payRateId == payRateId }
    }

    private var parsedFixedPay: Decimal? {
        let trimmed = fixedPayText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed)
    }

    func save() async -> Bool {
        guard canSave else { return false }

        await MainActor.run { isSaving = true }
        defer { Task { @MainActor in isSaving = false } }

        do {
            let uid = try await authRepository.ensureSignedInAnonymously()
            let now = Date()
            let shift: WorkShift
            switch workShiftCreateMode {
            case .fromTemplate:
                guard let template = selectedTemplate else { return false }
                let calendar = Calendar.current
                guard let start = Date.applyingTime(template.startTime, to: workShiftDate, calendar: calendar) else { return false }
                var end = Date.applyingTime(template.endTime, to: workShiftDate, calendar: calendar)
                if let e = end, e <= start {
                    end = calendar.date(byAdding: .day, value: 1, to: e)
                }
                let endAt = end ?? start.addingTimeInterval(3600 * 8)
                shift = WorkShift(
                    id: UUID().uuidString,
                    startAt: start,
                    endAt: endAt,
                    payType: template.payType,
                    payRateId: template.payRateId.isEmpty ? nil : template.payRateId,
                    hourlyRateId: template.hourlyRateId,
                    fixedPay: template.fixedPay,
                    companyName: nil,
                    templateId: template.id,
                    tagIds: [],
                    isActive: true,
                    createdAt: now,
                    updatedAt: now
                )
            case .newEntry:
                let trimmedCompany = companyNameText.trimmingCharacters(in: .whitespacesAndNewlines)
                let companyName: String? = payType == .fixed && !trimmedCompany.isEmpty ? trimmedCompany : nil
                shift = WorkShift(
                    id: UUID().uuidString,
                    startAt: startAt,
                    endAt: endAt,
                    payType: payType,
                    payRateId: payType == .hourly ? selectedPayRateId : nil,
                    hourlyRateId: payType == .hourly ? selectedHourlyRateId : nil,
                    fixedPay: payType == .fixed ? parsedFixedPay : nil,
                    companyName: companyName,
                    templateId: nil,
                    tagIds: [],
                    isActive: true,
                    createdAt: now,
                    updatedAt: now
                )
            }
            try await workShiftRepository.upsert(uid: uid, shift: shift)
            await MainActor.run { errorMessage = nil }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }
}
