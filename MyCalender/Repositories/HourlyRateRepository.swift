import Foundation
import FirebaseFirestore

protocol HourlyRateRepositoryProtocol: Sendable {
    func listActive(uid: String) async throws -> [HourlyRate]
    func listActiveByPayRate(uid: String, payRateId: PayRateID) async throws -> [HourlyRate]
    func add(uid: String, hourlyRate: HourlyRate) async throws
    func update(uid: String, hourlyRate: HourlyRate) async throws
    func deactivate(uid: String, hourlyRateId: HourlyRateID) async throws
}

actor FirestoreHourlyRateRepository: HourlyRateRepositoryProtocol {
    private let db = Firestore.firestore()

    func listActive(uid: String) async throws -> [HourlyRate] {
        let snapshot = try await db
            .collection(FirestorePaths.hourlyRates(uid: uid))
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        return try snapshot.documents.map { try mapHourlyRate(doc: $0) }
    }

    func listActiveByPayRate(uid: String, payRateId: PayRateID) async throws -> [HourlyRate] {
        let snapshot = try await db
            .collection(FirestorePaths.hourlyRates(uid: uid))
            .whereField("payRateId", isEqualTo: payRateId)
            .whereField("isActive", isEqualTo: true)
            .order(by: "amount")
            .getDocuments()
        return try snapshot.documents.map { try mapHourlyRate(doc: $0) }
    }

    func add(uid: String, hourlyRate: HourlyRate) async throws {
        let ref = await db.collection(FirestorePaths.hourlyRates(uid: uid)).document(hourlyRate.id)
        try await ref.setData(hourlyRate.toFirestoreData())
    }

    func update(uid: String, hourlyRate: HourlyRate) async throws {
        let ref = await db.collection(FirestorePaths.hourlyRates(uid: uid)).document(hourlyRate.id)
        var data = await hourlyRate.toFirestoreData()
        data.removeValue(forKey: "createdAt")
        try await ref.setData(data, merge: true)
    }

    func deactivate(uid: String, hourlyRateId: HourlyRateID) async throws {
        let ref = await db.collection(FirestorePaths.hourlyRates(uid: uid)).document(hourlyRateId)
        try await ref.updateData([
            "isActive": false,
            "updatedAt": FieldValue.serverTimestamp(),
        ])
    }

    private func mapHourlyRate(doc: QueryDocumentSnapshot) throws -> HourlyRate {
        let data = doc.data()
        return HourlyRate(
            id: doc.documentID,
            payRateId: try FirestoreMappers.string(data["payRateId"], key: "payRateId"),
            amount: (try FirestoreMappers.decimal(data["amount"], key: "amount")) ?? 0,
            isActive: (data["isActive"] as? Bool) ?? true,
            createdAt: (try? FirestoreMappers.date(data["createdAt"], key: "createdAt")) ?? .distantPast,
            updatedAt: (try? FirestoreMappers.date(data["updatedAt"], key: "updatedAt")) ?? .distantPast
        )
    }
}

private extension HourlyRate {
    func toFirestoreData() -> [String: Any] {
        [
            "payRateId": payRateId,
            "amount": (amount as NSDecimalNumber),
            "isActive": isActive,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
    }
}
