import Foundation
import Observation
import SwiftUI

/// 月次勤務グリッド用の1列（会社または固定給）
struct MonthlyWorkShiftColumn: Identifiable {
    let id: String
    let title: String
}

@Observable
final class MonthlyWorkShiftViewModel {
    private let authRepository: AuthRepositoryProtocol
    private let workShiftRepository: WorkShiftRepositoryProtocol
    private let payRateRepository: PayRateRepositoryProtocol
    private let hourlyRateRepository: HourlyRateRepositoryProtocol
    private let shiftTemplateRepository: ShiftTemplateRepositoryProtocol

    /// 表示する月（任意の日付でよい。月のみ使用）
    var month: Date
    var workShifts: [WorkShift] = []
    var payRates: [PayRate] = []
    var hourlyRates: [HourlyRate] = []
    var shiftTemplates: [ShiftTemplate] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private let calendar = Calendar.current
    private let fixedColumnId = "fixed"

    init(
        month: Date = Date(),
        authRepository: AuthRepositoryProtocol = FirebaseAuthRepository(),
        workShiftRepository: WorkShiftRepositoryProtocol = FirestoreWorkShiftRepository(),
        payRateRepository: PayRateRepositoryProtocol = FirestorePayRateRepository(),
        hourlyRateRepository: HourlyRateRepositoryProtocol = FirestoreHourlyRateRepository(),
        shiftTemplateRepository: ShiftTemplateRepositoryProtocol = FirestoreShiftTemplateRepository()
    ) {
        self.month = month
        self.authRepository = authRepository
        self.workShiftRepository = workShiftRepository
        self.payRateRepository = payRateRepository
        self.hourlyRateRepository = hourlyRateRepository
        self.shiftTemplateRepository = shiftTemplateRepository
    }

    /// 指定会社のシフトテンプレート一覧（空欄セル用ポップオーバーで表示）
    func shiftTemplates(forCompanyId companyId: String) -> [ShiftTemplate] {
        if companyId == fixedColumnId { return [] }
        return shiftTemplates.filter { $0.payRateId == companyId }
    }

    /// テンプレの稼ぎ額表示用（ポップオーバーで使用）
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
            return "¥\(NSDecimalNumber(decimal: rate.amount * hours).stringValue)"
        case .fixed:
            guard let fixed = template.fixedPay else { return nil }
            return "¥\(NSDecimalNumber(decimal: fixed).stringValue)"
        }
    }

    /// ボックス表示用：テンプレからならシフト名、それ以外は会社名（displayTitle）
    func shiftDisplayName(for shift: WorkShift) -> String {
        if let tid = shift.templateId,
           let t = shiftTemplates.first(where: { $0.id == tid }),
           !t.shiftName.isEmpty {
            return t.shiftName
        }
        return shift.displayTitle(payRates: payRates)
    }

    /// その月の全日（1日〜最終日）の startOfDay
    var daysInMonth: [Date] {
        month.daysInMonth(in: calendar)
    }

    /// 列定義：会社（PayRate）＋ 固定給がある場合は「固定給」を末尾に1列
    var companyColumns: [MonthlyWorkShiftColumn] {
        var cols = payRates.map { MonthlyWorkShiftColumn(id: $0.id, title: $0.title) }
        if workShifts.contains(where: { $0.payType == .fixed }) {
            cols.append(MonthlyWorkShiftColumn(id: fixedColumnId, title: "固定給"))
        }
        return cols
    }

    /// 指定日の、指定列に属するシフト一覧
    func shifts(on day: Date, columnId: String) -> [WorkShift] {
        let dayStart = day.startOfDay(in: calendar)
        let dayEnd = day.endOfDay(in: calendar)
        return workShifts.filter { shift in
            guard shift.startAt < dayEnd, shift.endAt > dayStart else { return false }
            if columnId == fixedColumnId {
                return shift.payType == .fixed
            }
            return shift.payRateId == columnId
        }
    }

    /// 指定日のその列での合計金額
    func dayEarnings(on day: Date, columnId: String) -> Decimal? {
        let list = shifts(on: day, columnId: columnId)
        guard !list.isEmpty else { return nil }
        var sum = Decimal.zero
        for s in list {
            if let e = s.totalEarnings(hourlyRates: hourlyRates, payRates: payRates) {
                sum += e
            }
        }
        return sum == 0 ? nil : sum
    }

    /// 指定日の全日合計
    func dayTotal(on day: Date) -> Decimal {
        var sum = Decimal.zero
        for col in companyColumns {
            if let e = dayEarnings(on: day, columnId: col.id) {
                sum += e
            }
        }
        return sum
    }

    /// 指定列の月間合計
    func columnMonthTotal(columnId: String) -> Decimal {
        var sum = Decimal.zero
        for day in daysInMonth {
            if let e = dayEarnings(on: day, columnId: columnId) {
                sum += e
            }
        }
        return sum
    }

    /// 月間全体の合計
    var grandTotal: Decimal {
        var sum = Decimal.zero
        for day in daysInMonth {
            sum += dayTotal(on: day)
        }
        return sum
    }

    func refresh() {
        Task { @MainActor in await refreshAsync() }
    }

    /// プルで更新・表示切替時の再読み込み用。完了まで await できる。
    func refreshAsync() async {
        await MainActor.run { isLoading = true }
        do {
            let start = month.startOfMonth(in: calendar)
            let end = month.endOfMonth(in: calendar)

            async let shiftsTask = workShiftRepository.listActiveOverlapping(start: start, end: end)
            async let payRatesTask = payRateRepository.listActive()
            async let hourlyRatesTask = hourlyRateRepository.listActive()
            async let templatesTask = shiftTemplateRepository.listActive()

            let (shifts, rates, hourly, templates) = try await (shiftsTask, payRatesTask, hourlyRatesTask, templatesTask)
            await MainActor.run {
                self.workShifts = shifts
                self.payRates = rates
                self.hourlyRates = hourly
                self.shiftTemplates = templates
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    /// 指定日の勤務をテンプレートから1件作成して保存し、refresh する
    func createShiftFromTemplate(_ template: ShiftTemplate, on date: Date) async throws {
        let calendar = Calendar.current
        let workShiftDate = calendar.startOfDay(for: date)
        guard let start = Date.applyingTime(template.startTime, to: workShiftDate, calendar: calendar) else {
            throw NSError(domain: "MonthlyWorkShift", code: 0, userInfo: [NSLocalizedDescriptionKey: "開始時刻の取得に失敗しました"])
        }
        var end = Date.applyingTime(template.endTime, to: workShiftDate, calendar: calendar)
        if let e = end, e <= start {
            end = calendar.date(byAdding: .day, value: 1, to: e)
        }
        let endAt = end ?? start.addingTimeInterval(3600 * 8)
        let now = Date()
        let shift = WorkShift(
            id: UUID().uuidString,
            startAt: start,
            endAt: endAt,
            breakMinutes: template.breakMinutes,
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
        try await workShiftRepository.upsert(shift: shift)
        await MainActor.run { refresh() }
    }

    /// シフトを削除（無効化）して refresh する
    func deleteWorkShift(_ shift: WorkShift) {
        Task { @MainActor in
            do {
                try await workShiftRepository.deactivate(shiftId: shift.id)
                errorMessage = nil
                withAnimation(.easeOut(duration: 0.25)) { refresh() }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
