import Foundation
import FirebaseFirestore

protocol ShiftTemplateRepositoryProtocol: Sendable {
    func listActive(uid: String) async throws -> [ShiftTemplate]
    func add(uid: String, template: ShiftTemplate) async throws
    func update(uid: String, template: ShiftTemplate) async throws
    func deactivate(uid: String, templateId: ShiftTemplateID) async throws
}

actor FirestoreShiftTemplateRepository: ShiftTemplateRepositoryProtocol {
    private let db = Firestore.firestore()

    func listActive(uid: String) async throws -> [ShiftTemplate] {
        let snapshot = try await db
            .collection(FirestorePaths.shiftTemplates(uid: uid))
            .whereField("isActive", isEqualTo: true)
            .order(by: "payRateId")
            .getDocuments()
        return try snapshot.documents.map { try mapTemplate(doc: $0) }
    }

    func add(uid: String, template: ShiftTemplate) async throws {
        let ref = await db.collection(FirestorePaths.shiftTemplates(uid: uid)).document(template.id)
        try await ref.setData(template.toFirestoreData())
    }

    func update(uid: String, template: ShiftTemplate) async throws {
        let ref = await db.collection(FirestorePaths.shiftTemplates(uid: uid)).document(template.id)
        var data = await template.toFirestoreData()
        data.removeValue(forKey: "createdAt")
        try await ref.setData(data, merge: true)
    }

    func deactivate(uid: String, templateId: ShiftTemplateID) async throws {
        let ref = await db.collection(FirestorePaths.shiftTemplates(uid: uid)).document(templateId)
        try await ref.updateData([
            "isActive": false,
            "updatedAt": FieldValue.serverTimestamp(),
        ])
    }

    private func mapTemplate(doc: QueryDocumentSnapshot) throws -> ShiftTemplate {
        let data = doc.data()
        let payTypeRaw = (data["payType"] as? String) ?? "hourly"
        let payType = WorkPayType(rawValue: payTypeRaw) ?? .hourly
        let shiftName = (data["shiftName"] as? String) ?? (data["title"] as? String) ?? ""
        // 後方互換: payRateId がない古いデータは空文字（一覧で「未設定」表示）
        let payRateId = (data["payRateId"] as? String) ?? ""

        let breakMinutes = (data["breakMinutes"] as? Int) ?? (data["breakMinutes"] as? Int64).map { Int($0) } ?? 0
        return ShiftTemplate(
            id: doc.documentID,
            payRateId: payRateId,
            hourlyRateId: data["hourlyRateId"] as? String,
            shiftName: shiftName,
            startTime: (data["startTime"] as? String) ?? "09:00",
            endTime: (data["endTime"] as? String) ?? "17:00",
            breakMinutes: breakMinutes,
            payType: payType,
            fixedPay: try FirestoreMappers.decimal(data["fixedPay"], key: "fixedPay"),
            isActive: (data["isActive"] as? Bool) ?? true,
            createdAt: (try? FirestoreMappers.date(data["createdAt"], key: "createdAt")) ?? .distantPast,
            updatedAt: (try? FirestoreMappers.date(data["updatedAt"], key: "updatedAt")) ?? .distantPast
        )
    }
}

private extension ShiftTemplate {
    func toFirestoreData() -> [String: Any] {
        var dict: [String: Any] = [
            "payRateId": payRateId,
            "shiftName": shiftName,
            "startTime": startTime,
            "endTime": endTime,
            "breakMinutes": breakMinutes,
            "payType": payType.rawValue,
            "isActive": isActive,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        if let hourlyRateId { dict["hourlyRateId"] = hourlyRateId }
        if let fixedPay { dict["fixedPay"] = (fixedPay as NSDecimalNumber) }
        return dict
    }
}
