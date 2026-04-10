import FirebaseFirestore
import Foundation

protocol EventTemplateRepositoryProtocol: Sendable {
    func listActive() async throws -> [EventTemplate]
    func add(template: EventTemplate) async throws
    func update(template: EventTemplate) async throws
    func deactivate(templateId: EventTemplateID) async throws
}

actor FirestoreEventTemplateRepository: EventTemplateRepositoryProtocol {
    private let db = Firestore.firestore()

    func listActive() async throws -> [EventTemplate] {
        let snapshot = try await db
            .collection(FirestorePaths.eventTemplates)
            .whereField("isActive", isEqualTo: true)
            .order(by: "title")
            .getDocuments()
        return try snapshot.documents.map { try mapTemplate(doc: $0) }
    }

    func add(template: EventTemplate) async throws {
        let ref = await db.collection(FirestorePaths.eventTemplates).document(template.id)
        try await ref.setData(template.toFirestoreData())
    }

    func update(template: EventTemplate) async throws {
        let ref = await db.collection(FirestorePaths.eventTemplates).document(template.id)
        var data = await template.toFirestoreData()
        data.removeValue(forKey: "createdAt")
        try await ref.setData(data, merge: true)
    }

    func deactivate(templateId: EventTemplateID) async throws {
        let ref = await db.collection(FirestorePaths.eventTemplates).document(templateId)
        try await ref.updateData([
            "isActive": false,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    private func mapTemplate(doc: QueryDocumentSnapshot) throws -> EventTemplate {
        let data = doc.data()
        return try EventTemplate(
            id: doc.documentID,
            title: FirestoreMappers.string(data["title"], key: "title"),
            note: data["note"] as? String,
            startTime: (data["startTime"] as? String) ?? "09:00",
            endTime: (data["endTime"] as? String) ?? "10:00",
            tagIds: FirestoreMappers.stringArray(data["tagIds"], key: "tagIds"),
            isActive: (data["isActive"] as? Bool) ?? true,
            createdAt: (try? FirestoreMappers.date(data["createdAt"], key: "createdAt")) ?? .distantPast,
            updatedAt: (try? FirestoreMappers.date(data["updatedAt"], key: "updatedAt")) ?? .distantPast
        )
    }
}

private extension EventTemplate {
    func toFirestoreData() -> [String: Any] {
        var dict: [String: Any] = [
            "title": title,
            "startTime": startTime,
            "endTime": endTime,
            "tagIds": tagIds,
            "isActive": isActive,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let note { dict["note"] = note }
        return dict
    }
}
