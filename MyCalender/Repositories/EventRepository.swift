import FirebaseFirestore
import Foundation

protocol EventRepositoryProtocol: Sendable {
    func listActiveOverlapping(start: Date, end: Date) async throws -> [Event]
    func upsert(event: Event) async throws
    func deactivate(eventId: EventID) async throws
}

actor FirestoreEventRepository: EventRepositoryProtocol {
    private let db = Firestore.firestore()

    func listActiveOverlapping(start: Date, end: Date) async throws -> [Event] {
        // NOTE: FirestoreはOR条件/2フィールドの範囲で制限があるため、
        // ここでは「startAt < end」の範囲で拾って、クライアントで endAt > start をフィルタする。
        let snapshot = try await db
            .collection(FirestorePaths.events)
            .whereField("isActive", isEqualTo: true)
            .whereField("startAt", isLessThan: end)
            .order(by: "startAt")
            .getDocuments()

        return try snapshot.documents
            .compactMap { doc in try mapEvent(doc: doc) }
            .filter { $0.endAt > start }
    }

    func upsert(event: Event) async throws {
        let ref = await db.collection(FirestorePaths.events).document(event.id)
        var data = await event.toFirestoreData()
        let snapshot = try await ref.getDocument()
        if snapshot.exists {
            data.removeValue(forKey: "createdAt")
        }
        try await ref.setData(data, merge: true)
    }

    func deactivate(eventId: EventID) async throws {
        let ref = await db.collection(FirestorePaths.events).document(eventId)
        try await ref.updateData([
            "isActive": false,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    private func mapEvent(doc: QueryDocumentSnapshot) throws -> Event {
        let data = doc.data()
        let typeRaw = (data["type"] as? String) ?? "normal"
        let type = EventType(rawValue: typeRaw) ?? .normal

        return try Event(
            id: doc.documentID,
            type: type,
            title: FirestoreMappers.string(data["title"], key: "title"),
            startAt: FirestoreMappers.date(data["startAt"], key: "startAt"),
            endAt: FirestoreMappers.date(data["endAt"], key: "endAt"),
            note: data["note"] as? String,
            tagIds: FirestoreMappers.stringArray(data["tagIds"], key: "tagIds"),
            isActive: (data["isActive"] as? Bool) ?? true,
            createdAt: (try? FirestoreMappers.date(data["createdAt"], key: "createdAt")) ?? Date.distantPast,
            updatedAt: (try? FirestoreMappers.date(data["updatedAt"], key: "updatedAt")) ?? Date.distantPast
        )
    }
}

private extension Event {
    func toFirestoreData() -> [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "title": title,
            "startAt": Timestamp(date: startAt),
            "endAt": Timestamp(date: endAt),
            "tagIds": tagIds,
            "isActive": isActive,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let note { dict["note"] = note }

        // createdAtは初回のみセットしたいので merge で守る
        dict["createdAt"] = FieldValue.serverTimestamp()
        return dict
    }
}
