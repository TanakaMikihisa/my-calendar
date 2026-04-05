import Foundation
import Observation

@Observable
final class SettingsViewModel {
    private let authRepository: AuthRepositoryProtocol
    private let tagRepository: TagRepositoryProtocol
    private let payRateRepository: PayRateRepositoryProtocol
    private let hourlyRateRepository: HourlyRateRepositoryProtocol
    private let shiftTemplateRepository: ShiftTemplateRepositoryProtocol

    var tags: [Tag] = []
    var payRates: [PayRate] = []
    var hourlyRates: [HourlyRate] = []
    var shiftTemplates: [ShiftTemplate] = []
    var isLoading = false
    var errorMessage: String?

    init(
        authRepository: AuthRepositoryProtocol = FirebaseAuthRepository(),
        tagRepository: TagRepositoryProtocol = FirestoreTagRepository(),
        payRateRepository: PayRateRepositoryProtocol = FirestorePayRateRepository(),
        hourlyRateRepository: HourlyRateRepositoryProtocol = FirestoreHourlyRateRepository(),
        shiftTemplateRepository: ShiftTemplateRepositoryProtocol = FirestoreShiftTemplateRepository()
    ) {
        self.authRepository = authRepository
        self.tagRepository = tagRepository
        self.payRateRepository = payRateRepository
        self.hourlyRateRepository = hourlyRateRepository
        self.shiftTemplateRepository = shiftTemplateRepository
    }

    func loadTags() {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            do {
                tags = try await tagRepository.listActive()
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
                payRates = try await payRateRepository.listActive()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadShiftTemplates() {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            do {
                shiftTemplates = try await shiftTemplateRepository.listActive()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadHourlyRates() {
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            do {
                hourlyRates = try await hourlyRateRepository.listActive()
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
                async let tagsTask = tagRepository.listActive()
                async let payRatesTask = payRateRepository.listActive()
                async let hourlyRatesTask = hourlyRateRepository.listActive()
                async let templatesTask = shiftTemplateRepository.listActive()
                tags = try await tagsTask
                payRates = try await payRatesTask
                hourlyRates = try await hourlyRatesTask
                shiftTemplates = try await templatesTask
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
            let tag = Tag(
                id: UUID().uuidString,
                name: trimmed,
                colorHex: colorHex,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await tagRepository.add(tag: tag)
            await MainActor.run { loadTags() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func updateTag(_ tag: Tag) async -> Bool {
        do {
            var t = tag
            t.updatedAt = Date()
            try await tagRepository.update(tag: t)
            await MainActor.run { loadTags() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func deactivateTag(id: TagID) async -> Bool {
        do {
            try await tagRepository.deactivate(tagId: id)
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
            let payRate = PayRate(
                id: UUID().uuidString,
                title: trimmed,
                hourlyWage: hourlyWage,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await payRateRepository.add(payRate: payRate)
            await MainActor.run { loadPayRates() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func updatePayRate(_ payRate: PayRate) async -> Bool {
        do {
            var p = payRate
            p.updatedAt = Date()
            try await payRateRepository.update(payRate: p)
            await MainActor.run { loadPayRates() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func deactivatePayRate(id: PayRateID) async -> Bool {
        do {
            try await payRateRepository.deactivate(payRateId: id)
            await MainActor.run { loadPayRates() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    // MARK: - HourlyRate

    func addHourlyRate(payRateId: PayRateID, amount: Decimal) async -> Bool {
        guard !payRateId.isEmpty else { return false }
        do {
            let rate = HourlyRate(
                id: UUID().uuidString,
                payRateId: payRateId,
                amount: amount,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await hourlyRateRepository.add(hourlyRate: rate)
            await MainActor.run { loadHourlyRates() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func updateHourlyRate(_ rate: HourlyRate) async -> Bool {
        do {
            var r = rate
            r.updatedAt = Date()
            try await hourlyRateRepository.update(hourlyRate: r)
            await MainActor.run { loadHourlyRates() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func deactivateHourlyRate(id: HourlyRateID) async -> Bool {
        do {
            try await hourlyRateRepository.deactivate(hourlyRateId: id)
            await MainActor.run { loadHourlyRates() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    // MARK: - ShiftTemplate

    func addShiftTemplate(payRateId: PayRateID, shiftName: String, startTime: String, endTime: String, breakMinutes: Int, payType: WorkPayType, hourlyRateId: HourlyRateID?, fixedPay: Decimal?) async -> Bool {
        let shiftTrimmed = shiftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !shiftTrimmed.isEmpty, !payRateId.isEmpty else { return false }
        do {
            let template = ShiftTemplate(
                id: UUID().uuidString,
                payRateId: payRateId,
                hourlyRateId: payType == .hourly ? hourlyRateId : nil,
                shiftName: shiftTrimmed,
                startTime: startTime,
                endTime: endTime,
                breakMinutes: max(0, breakMinutes),
                payType: payType,
                fixedPay: payType == .fixed ? fixedPay : nil,
                isActive: true,
                createdAt: Date(),
                updatedAt: Date()
            )
            try await shiftTemplateRepository.add(template: template)
            await MainActor.run { loadShiftTemplates() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func updateShiftTemplate(_ template: ShiftTemplate) async -> Bool {
        do {
            var t = template
            t.updatedAt = Date()
            try await shiftTemplateRepository.update(template: t)
            await MainActor.run { loadShiftTemplates() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }

    func deactivateShiftTemplate(id: ShiftTemplateID) async -> Bool {
        do {
            try await shiftTemplateRepository.deactivate(templateId: id)
            await MainActor.run { loadShiftTemplates() }
            return true
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return false
        }
    }
}
