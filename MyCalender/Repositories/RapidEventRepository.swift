import FirebaseFirestore
import Foundation

protocol RapidEventRepositoryProtocol: Sendable {
    func upsert(rapidEvent: RapidEvent) async throws
    func deactivate(rapidEventId: RapidEventID) async throws
    func listPending() async throws -> [RapidEvent]
    /// 通知済み（`isNotified == true`）で、まだ無効化されていない単発通知。新しい順。
    func listNotified() async throws -> [RapidEvent]
}

actor FirestoreRapidEventRepository: RapidEventRepositoryProtocol {
    private let db = Firestore.firestore()

    func upsert(rapidEvent: RapidEvent) async throws {
        let ref = await db.collection(FirestorePaths.rapidEvents).document(rapidEvent.id)
        var data = await rapidEvent.toFirestoreData()
        let snapshot = try await ref.getDocument()
        if snapshot.exists {
            data.removeValue(forKey: "createdAt")
        }
        try await ref.setData(data, merge: true)
    }

    func deactivate(rapidEventId: RapidEventID) async throws {
        let ref = await db.collection(FirestorePaths.rapidEvents).document(rapidEventId)
        try await ref.updateData([
            "isActive": false,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func listPending() async throws -> [RapidEvent] {
        let snapshot = try await db
            .collection(FirestorePaths.rapidEvents)
            .whereField("isActive", isEqualTo: true)
            .whereField("isNotified", isEqualTo: false)
            .order(by: "notifyAt")
            .getDocuments()

        let all = try snapshot.documents.compactMap { try mapRapidEvent(doc: $0) }
        let now = Date()
        let dueIds = all.filter { $0.notifyAt <= now }.map(\.id)
        if !dueIds.isEmpty {
            for id in dueIds {
                let ref = await db.collection(FirestorePaths.rapidEvents).document(id)
                try await ref.updateData([
                    "isNotified": true,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            }
        }
        return all.filter { $0.notifyAt > now }
    }

    /// `isActive` + `isNotified` + `notifyAt` の複合インデックスが必要な場合、初回クエリ時に Firebase コンソールのリンクから作成してください。
    func listNotified() async throws -> [RapidEvent] {
        let snapshot = try await db
            .collection(FirestorePaths.rapidEvents)
            .whereField("isActive", isEqualTo: true)
            .whereField("isNotified", isEqualTo: true)
            .order(by: "notifyAt", descending: true)
            .getDocuments()

        return try snapshot.documents.compactMap { try mapRapidEvent(doc: $0) }
    }

    private func mapRapidEvent(doc: QueryDocumentSnapshot) throws -> RapidEvent {
        let data = doc.data()
        return try RapidEvent(
            id: doc.documentID,
            notifyAt: FirestoreMappers.date(data["notifyAt"], key: "notifyAt"),
            title: FirestoreMappers.string(data["title"], key: "title"),
            body: FirestoreMappers.string(data["body"], key: "body"),
            tagId: data["tagId"] as? String,
            isNotified: (data["isNotified"] as? Bool) ?? false,
            isActive: (data["isActive"] as? Bool) ?? true,
            createdAt: (try? FirestoreMappers.date(data["createdAt"], key: "createdAt")) ?? Date.distantPast,
            updatedAt: (try? FirestoreMappers.date(data["updatedAt"], key: "updatedAt")) ?? Date.distantPast
        )
    }
}

private extension RapidEvent {
    func toFirestoreData() -> [String: Any] {
        var dict: [String: Any] = [
            "notifyAt": Timestamp(date: notifyAt),
            "title": title,
            "body": body,
            "isNotified": isNotified,
            "isActive": isActive,
            "updatedAt": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let tagId {
            dict["tagId"] = tagId
        }
        return dict
    }
}
