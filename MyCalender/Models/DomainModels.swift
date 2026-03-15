import Foundation
import FirebaseFirestore

enum EventType: String, Sendable, Codable {
    case normal
}

enum WorkPayType: String, Sendable, Codable {
    case hourly
    case fixed
}

struct Event: Identifiable, Sendable, Hashable {
    var id: EventID
    var type: EventType
    var title: String
    var startAt: Date
    var endAt: Date
    var note: String?
    var tagIds: [TagID]
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct WorkShift: Identifiable, Sendable, Hashable {
    var id: WorkShiftID
    var startAt: Date
    var endAt: Date
    var payType: WorkPayType
    var payRateId: PayRateID?
    /// 時給のときどれを使うか。IDで参照するので変更が全体に反映される。
    var hourlyRateId: HourlyRateID?
    var fixedPay: Decimal?
    /// 固定給のときの表示用会社名。時給のときは payRateId から取得するため省略可。
    var companyName: String?
    var templateId: ShiftTemplateID?
    var tagIds: [TagID]
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct ShiftTemplate: Identifiable, Sendable, Hashable {
    var id: ShiftTemplateID
    /// 紐づく会社（1会社に複数テンプレ・時給パターン）
    var payRateId: PayRateID
    /// 時給のときどれを使うか。ID参照で変更が全体に反映される。
    var hourlyRateId: HourlyRateID?
    /// シフト（例: 週末夜）
    var shiftName: String
    /// "HH:mm"
    var startTime: String
    /// "HH:mm"（日跨ぎ可）
    var endTime: String
    var payType: WorkPayType
    var fixedPay: Decimal?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct PayRate: Identifiable, Sendable, Hashable {
    var id: PayRateID
    var title: String
    /// 後方互換用。時給は HourlyRate で複数管理し、ここは使わない（0 or 未使用）
    var hourlyWage: Decimal
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

/// 会社に紐づく時給パターン（名前なし、IDで参照して変更が全体に反映される）
struct HourlyRate: Identifiable, Sendable, Hashable {
    var id: HourlyRateID
    var payRateId: PayRateID
    var amount: Decimal
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct Tag: Identifiable, Sendable, Hashable {
    var id: TagID
    var name: String
    var colorHex: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
}

/// 表示用の集約モデル（Firestoreの正とは別）
struct Day: Sendable, Hashable {
    var date: Date
    var events: [Event]
    var workShifts: [WorkShift]
    var memo: String?
    var condition: String?
}

