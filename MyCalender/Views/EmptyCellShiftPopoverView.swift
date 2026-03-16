import SwiftUI

/// 月次グリッドの空欄セルタップ時に表示。その会社のシフト一覧（テンプレ）と「新規作成」を表示する独自 View。
struct EmptyCellShiftPopoverView: View {
    @Bindable var viewModel: MonthlyWorkShiftViewModel
    var companyId: String
    var companyTitle: String
    var date: Date
    var onDismiss: () -> Void
    var onRequestNewEntry: () -> Void

    private let calendar = Calendar.current
    @State private var isCreatingFromTemplate = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    private var dayLabel: String {
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        return "\(m)月\(d)日"
    }

    private var templates: [ShiftTemplate] {
        viewModel.shiftTemplates(forCompanyId: companyId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()
            if templates.isEmpty {
                emptyTemplatesView
            } else {
                templateListView
            }
            Divider()
            newEntryButton
        }
        .frame(minWidth: 260, maxWidth: 320)
        .alert("エラー", isPresented: $showErrorAlert) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("シフトを選択してください。")
                .font(.title3.weight(.semibold))
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("日付: \(dayLabel)")
                    .font(.subheadline)
                Text("会社: \(companyTitle)")
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
    }

    private var emptyTemplatesView: some View {
        Text("この会社のシフトテンプレートがありません。")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var templateListView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(templates) { template in
                    Button {
                        FeedBack().feedback(.medium)
                        addShiftFromTemplate(template)
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.shiftName)
                                    .foregroundStyle(.primary)
                                Text("\(template.startTime)〜\(template.endTime)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let earnings = viewModel.templateEarningsDisplay(template) {
                                    Text(earnings)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isCreatingFromTemplate)
                }
            }
        }
        .frame(maxHeight: 220)
    }

    private var newEntryButton: some View {
        Button {
            FeedBack().feedback(.medium)
            onRequestNewEntry()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("新規作成")
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .padding(16)
    }

    private func addShiftFromTemplate(_ template: ShiftTemplate) {
        isCreatingFromTemplate = true
        Task {
            do {
                try await viewModel.createShiftFromTemplate(template, on: date)
                await MainActor.run {
                    isCreatingFromTemplate = false
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    isCreatingFromTemplate = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}
