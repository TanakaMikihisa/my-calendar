import Foundation
import Observation

@Observable
final class SettingsViewModel {
    private let authRepository: AuthRepositoryProtocol
    private let tagRepository: TagRepositoryProtocol
    private let payRateRepository: PayRateRepositoryProtocol

    var tags: [Tag] = []
    var payRates: [PayRate] = []
    var isLoading = false
    var errorMessage: String?

    init(
        authRepository: AuthRepositoryProtocol = FirebaseAuthRepository(),
        tagRepository: TagRepositoryProtocol = FirestoreTagRepository(),
        payRateRepository: PayRateRepositoryProtocol = FirestorePayRateRepository()
    ) {
        self.authRepository = authRepository
        self.tagRepository = tagRepository
        self.payRateRepository = payRateRepository
    }

    func loadTags() {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            do {
                let uid = try await authRepository.ensureSignedInAnonymously()
                tags = try await tagRepository.listActive(uid: uid)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadPayRates() {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            do {
                let uid = try await authRepository.ensureSignedInAnonymously()
                payRates = try await payRateRepository.listActive(uid: uid)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadAll() {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            do {
                let uid = try await authRepository.ensureSignedInAnonymously()
                async let tagsTask = tagRepository.listActive(uid: uid)
                async let payRatesTask = payRateRepository.listActive(uid: uid)
                tags = try await tagsTask
                payRates = try await payRatesTask
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func addTag(name: String, colorHex: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            let uid = try await authRepository.ensureSignedInAnonymously()
            let tag = Tag(
                id: UUID().uuidString,
                name: trimmed,
                colorHex: colorHex,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await tagRepository.add(uid: uid, tag: tag)
            await MainActor.run { loadTags() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func updateTag(_ tag: Tag) async -> Bool {
        do {
            let uid = try await authRepository.ensureSignedInAnonymously()
            var t = tag
            t.updatedAt = Date()
            try await tagRepository.update(uid: uid, tag: t)
            await MainActor.run { loadTags() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func deactivateTag(id: TagID) async -> Bool {
        do {
            let uid = try await authRepository.ensureSignedInAnonymously()
            try await tagRepository.deactivate(uid: uid, tagId: id)
            await MainActor.run { loadTags() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func addPayRate(title: String, hourlyWage: Decimal) async -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            let uid = try await authRepository.ensureSignedInAnonymously()
            let payRate = PayRate(
                id: UUID().uuidString,
                title: trimmed,
                hourlyWage: hourlyWage,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await payRateRepository.add(uid: uid, payRate: payRate)
            await MainActor.run { loadPayRates() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func updatePayRate(_ payRate: PayRate) async -> Bool {
        do {
            let uid = try await authRepository.ensureSignedInAnonymously()
            var p = payRate
            p.updatedAt = Date()
            try await payRateRepository.update(uid: uid, payRate: p)
            await MainActor.run { loadPayRates() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func deactivatePayRate(id: PayRateID) async -> Bool {
        do {
            let uid = try await authRepository.ensureSignedInAnonymously()
            try await payRateRepository.deactivate(uid: uid, payRateId: id)
            await MainActor.run { loadPayRates() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }
}
