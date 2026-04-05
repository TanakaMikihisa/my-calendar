import FirebaseFirestore
import Foundation

protocol PayRateRepositoryProtocol: Sendable {
    func listActive() async throws -> [PayRate]
    func add(payRate: PayRate) async throws
    func update(payRate: PayRate) async throws
    func deactivate(payRateId: PayRateID) async throws
}

actor FirestorePayRateRepository: PayRateRepositoryProtocol {
    private let db = Firestore.firestore()

    func listActive() async throws -> [PayRate] {
        let snapshot = try await db
            .collection(FirestorePaths.payRates)
            .whereField("isActive", isEqualTo: true)
            .order(by: "title")
            .getDocuments()
        return try snapshot.documents.map { try mapPayRate(doc: $0) }
    }

    func add(payRate: PayRate) async throws {
        let ref = await db.collection(FirestorePaths.payRates).document(payRate.id)
        try await ref.setData(payRate.toFirestoreData())
    }

    func update(payRate: PayRate) async throws {
        let ref = await db.collection(FirestorePaths.payRates).document(payRate.id)
        var data = await payRate.toFirestoreData()
        data.removeValue(forKey: "createdAt")
        try await ref.setData(data, merge: true)
    }

    func deactivate(payRateId: PayRateID) async throws {
        let ref = await db.collection(FirestorePaths.payRates).document(payRateId)
        try await ref.updateData([
            "isActive": false,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    private func mapPayRate(doc: QueryDocumentSnapshot) throws -> PayRate {
        let data = doc.data()
        return try PayRate(
            id: doc.documentID,
            title: FirestoreMappers.string(data["title"], key: "title"),
            hourlyWage: (FirestoreMappers.decimal(data["hourlyWage"], key: "hourlyWage")) ?? 0,
            isActive: (data["isActive"] as? Bool) ?? true,
            createdAt: (try? FirestoreMappers.date(data["createdAt"], key: "createdAt")) ?? .distantPast,
            updatedAt: (try? FirestoreMappers.date(data["updatedAt"], key: "updatedAt")) ?? .distantPast
        )
    }
}

private extension PayRate {
    func toFirestoreData() -> [String: Any] {
        [
            "title": title,
            "hourlyWage": hourlyWage as NSDecimalNumber,
            "isActive": isActive,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}
