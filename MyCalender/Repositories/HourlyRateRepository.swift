import FirebaseFirestore
import Foundation

protocol HourlyRateRepositoryProtocol: Sendable {
    func listActive() async throws -> [HourlyRate]
    func listActiveByPayRate(payRateId: PayRateID) async throws -> [HourlyRate]
    func add(hourlyRate: HourlyRate) async throws
    func update(hourlyRate: HourlyRate) async throws
    func deactivate(hourlyRateId: HourlyRateID) async throws
}

actor FirestoreHourlyRateRepository: HourlyRateRepositoryProtocol {
    private let db = Firestore.firestore()

    func listActive() async throws -> [HourlyRate] {
        let snapshot = try await db
            .collection(FirestorePaths.hourlyRates)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        return try snapshot.documents.map { try mapHourlyRate(doc: $0) }
    }

    func listActiveByPayRate(payRateId: PayRateID) async throws -> [HourlyRate] {
        let snapshot = try await db
            .collection(FirestorePaths.hourlyRates)
            .whereField("payRateId", isEqualTo: payRateId)
            .whereField("isActive", isEqualTo: true)
            .order(by: "amount")
            .getDocuments()
        return try snapshot.documents.map { try mapHourlyRate(doc: $0) }
    }

    func add(hourlyRate: HourlyRate) async throws {
        let ref = await db.collection(FirestorePaths.hourlyRates).document(hourlyRate.id)
        try await ref.setData(hourlyRate.toFirestoreData())
    }

    func update(hourlyRate: HourlyRate) async throws {
        let ref = await db.collection(FirestorePaths.hourlyRates).document(hourlyRate.id)
        var data = await hourlyRate.toFirestoreData()
        data.removeValue(forKey: "createdAt")
        try await ref.setData(data, merge: true)
    }

    func deactivate(hourlyRateId: HourlyRateID) async throws {
        let ref = await db.collection(FirestorePaths.hourlyRates).document(hourlyRateId)
        try await ref.updateData([
            "isActive": false,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    private func mapHourlyRate(doc: QueryDocumentSnapshot) throws -> HourlyRate {
        let data = doc.data()
        return try HourlyRate(
            id: doc.documentID,
            payRateId: FirestoreMappers.string(data["payRateId"], key: "payRateId"),
            amount: (FirestoreMappers.decimal(data["amount"], key: "amount")) ?? 0,
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
            "amount": amount as NSDecimalNumber,
            "isActive": isActive,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}
