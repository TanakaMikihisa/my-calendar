import SwiftUI

struct EditWorkShiftSheet: View {
    @Environment(\.dismiss) private var dismiss
    var shift: WorkShift
    var tags: [Tag]
    var onSaved: () -> Void
    /// 削除成功時に呼ぶ（詳細画面を閉じる場合に指定）。未指定時は onSaved を呼ぶ
    var onDeleted: (() -> Void)? = nil

    @State private var viewModel: EditWorkShiftViewModel
    @State private var showErrorAlert = false
    @State private var showDeleteConfirm = false

    init(shift: WorkShift, tags: [Tag], onSaved: @escaping () -> Void, onDeleted: (() -> Void)? = nil) {
        self.shift = shift
        self.tags = tags
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _viewModel = State(initialValue: EditWorkShiftViewModel(shift: shift))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("勤務時間") {
                    DatePicker("開始", selection: $viewModel.startAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("終了", selection: $viewModel.endAt, displayedComponents: [.date, .hourAndMinute])
                    TextField("休憩時間（分）", text: $viewModel.breakMinutesText)
                        .keyboardType(.numberPad)
                }
                Section("給与") {
                    Picker("種別", selection: $viewModel.payType) {
                        Text("時給").tag(WorkPayType.hourly)
                        Text("固定給").tag(WorkPayType.fixed)
                    }
                    .pickerStyle(.segmented)
                    if viewModel.payType == .hourly {
                        if viewModel.payRates.isEmpty {
                            Text("会社がありません。設定から追加できます。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.payRates) { rate in
                                Button {
                                    FeedBack().feedback(.light)
                                    viewModel.selectedPayRateId = viewModel.selectedPayRateId == rate.id ? nil : rate.id
                                    viewModel.selectedHourlyRateId = nil
                                } label: {
                                    HStack {
                                        Text(rate.title)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if viewModel.selectedPayRateId == rate.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                }
                            }
                            if viewModel.selectedPayRateId != nil, !viewModel.hourlyRatesForSelectedCompany.isEmpty {
                                ForEach(viewModel.hourlyRatesForSelectedCompany) { rate in
                                    Button {
                                        FeedBack().feedback(.light)
                                        viewModel.selectedHourlyRateId = viewModel.selectedHourlyRateId == rate.id ? nil : rate.id
                                    } label: {
                                        HStack {
                                            Text(rate.displayLabel())
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            if viewModel.selectedHourlyRateId == rate.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.tint)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if viewModel.payType == .fixed {
                        TextField("会社名", text: $viewModel.companyNameText)
                            .textContentType(.organizationName)
                        TextField("金額", text: $viewModel.fixedPayText)
                            .keyboardType(.decimalPad)
                    }
                }
                Section("タグ") {
                    if viewModel.tags.isEmpty {
                        Text("タグがありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.tags) { tag in
                            Button {
                                FeedBack().feedback(.light)
                                viewModel.toggleTag(tag.id)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color.from(hex: tag.colorHex))
                                        .frame(width: 20, height: 20)
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if viewModel.selectedTagIds.contains(tag.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                }
                Section {
                    Button("勤務を削除", role: .destructive) {
                        FeedBack().feedback(.heavy)
                        showDeleteConfirm = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("勤務を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        FeedBack().feedback(.light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        FeedBack().feedback(.medium)
                        Task {
                            let success = await viewModel.save()
                            if success {
                                onSaved()
                                dismiss()
                            } else {
                                showErrorAlert = true
                            }
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.isSaving)
                }
            }
            .onAppear {
                viewModel.loadTags()
                viewModel.loadPayRates()
                viewModel.loadHourlyRates()
            }
            .alert("エラー", isPresented: $showErrorAlert) {
                Button("OK") {
                    FeedBack().feedback(.light)
                    showErrorAlert = false
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("勤務を削除しますか？", isPresented: $showDeleteConfirm) {
                Button("キャンセル", role: .cancel) {
                    FeedBack().feedback(.light)
                    showDeleteConfirm = false
                }
                Button("削除", role: .destructive) {
                    FeedBack().feedback(.heavy)
                    Task {
                        let success = await viewModel.delete()
                        if success {
                            (onDeleted ?? onSaved)()
                            dismiss()
                        } else {
                            showErrorAlert = true
                        }
                    }
                }
            } message: {
                Text("この操作は取り消せません。")
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: today)!
    let end = cal.date(bySettingHour: 17, minute: 0, second: 0, of: today)!
    let shift = WorkShift(id: "ps1", startAt: start, endAt: end, breakMinutes: 0, payType: .hourly, payRateId: nil, hourlyRateId: nil, fixedPay: nil, companyName: nil, templateId: nil, tagIds: [], isActive: true, createdAt: .distantPast, updatedAt: .distantPast)
    let tags: [Tag] = []
    return EditWorkShiftSheet(shift: shift, tags: tags) {}
}
