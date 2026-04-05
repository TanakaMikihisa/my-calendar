import FirebaseFirestore
import Foundation

protocol WorkShiftRepositoryProtocol: Sendable {
    func listActiveOverlapping(start: Date, end: Date) async throws -> [WorkShift]
    func upsert(shift: WorkShift) async throws
    func deactivate(shiftId: WorkShiftID) async throws
}

actor FirestoreWorkShiftRepository: WorkShiftRepositoryProtocol {
    private let db = Firestore.firestore()

    func listActiveOverlapping(start: Date, end: Date) async throws -> [WorkShift] {
        let snapshot = try await db
            .collection(FirestorePaths.workShifts)
            .whereField("isActive", isEqualTo: true)
            .whereField("startAt", isLessThan: end)
            .order(by: "startAt")
            .getDocuments()

        return try snapshot.documents
            .compactMap { doc in try mapShift(doc: doc) }
            .filter { $0.endAt > start }
    }

    func upsert(shift: WorkShift) async throws {
        let ref = await db.collection(FirestorePaths.workShifts).document(shift.id)
        var data = await shift.toFirestoreData()
        let snapshot = try await ref.getDocument()
        if snapshot.exists {
            data.removeValue(forKey: "createdAt")
        }
        try await ref.setData(data, merge: true)
    }

    func deactivate(shiftId: WorkShiftID) async throws {
        let ref = await db.collection(FirestorePaths.workShifts).document(shiftId)
        try await ref.updateData([
            "isActive": false,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    private func mapShift(doc: QueryDocumentSnapshot) throws -> WorkShift {
        let data = doc.data()
        let payTypeRaw = (data["payType"] as? String) ?? "hourly"
        let payType = WorkPayType(rawValue: payTypeRaw) ?? .hourly

        let breakMinutes = (data["breakMinutes"] as? Int) ?? (data["breakMinutes"] as? Int64).map { Int($0) } ?? 0
        return try WorkShift(
            id: doc.documentID,
            startAt: FirestoreMappers.date(data["startAt"], key: "startAt"),
            endAt: FirestoreMappers.date(data["endAt"], key: "endAt"),
            breakMinutes: breakMinutes,
            payType: payType,
            payRateId: data["payRateId"] as? String,
            hourlyRateId: data["hourlyRateId"] as? String,
            fixedPay: FirestoreMappers.decimal(data["fixedPay"], key: "fixedPay"),
            companyName: data["companyName"] as? String,
            templateId: data["templateId"] as? String,
            tagIds: FirestoreMappers.stringArray(data["tagIds"], key: "tagIds"),
            isActive: (data["isActive"] as? Bool) ?? true,
            createdAt: (try? FirestoreMappers.date(data["createdAt"], key: "createdAt")) ?? Date.distantPast,
            updatedAt: (try? FirestoreMappers.date(data["updatedAt"], key: "updatedAt")) ?? Date.distantPast
        )
    }
}

private extension WorkShift {
    func toFirestoreData() -> [String: Any] {
        var dict: [String: Any] = [
            "startAt": Timestamp(date: startAt),
            "endAt": Timestamp(date: endAt),
            "breakMinutes": breakMinutes,
            "payType": payType.rawValue,
            "tagIds": tagIds,
            "isActive": isActive,
            "updatedAt": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]

        if let payRateId { dict["payRateId"] = payRateId }
        if let hourlyRateId { dict["hourlyRateId"] = hourlyRateId }
        if let companyName { dict["companyName"] = companyName }
        if let templateId { dict["templateId"] = templateId }
        if let fixedPay { dict["fixedPay"] = (fixedPay as NSDecimalNumber) }

        return dict
    }
}
