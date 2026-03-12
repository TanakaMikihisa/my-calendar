import SwiftUI

enum CreateItemKind: String, CaseIterable, Identifiable {
    case event = "イベント"
    case workShift = "バイト"

    var id: String { rawValue }
}

struct CreateItemSheet: View {
    @Environment(\.dismiss) private var dismiss

    var initialDate: Date?
    var onSaved: () -> Void

    @State private var kind: CreateItemKind = .event
    @State private var eventViewModel: CreateEventViewModel?
    @State private var workShiftViewModel: CreateWorkShiftViewModel?
    @State private var showErrorAlert = false
    @State private var showSettingsSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section("種類") {
                    HStack(spacing: 8) {
                        ForEach(CreateItemKind.allCases) { k in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    kind = k
                                }
                            } label: {
                                Text(k.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        kind == k
                                            ? Color.accentColor
                                            : Color(.systemGray5).opacity(0.6),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                switch kind {
                case .event:
                    if let eventViewModel {
                        CreateEventForm(viewModel: eventViewModel)
                    }
                case .workShift:
                    if let workShiftViewModel {
                        CreateWorkShiftForm(viewModel: workShiftViewModel)
                    }
                }
            }
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showSettingsSheet = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        if kind == .event, let eventViewModel {
                            Button("保存") {
                                Task {
                                    let success = await eventViewModel.save()
                                    if success {
                                        dismiss()
                                        onSaved()
                                    } else {
                                        showErrorAlert = true
                                    }
                                }
                            }
                            .disabled(!eventViewModel.canSave || eventViewModel.isSaving)
                        }
                        if kind == .workShift, let workShiftViewModel {
                            Button("保存") {
                                Task {
                                    let success = await workShiftViewModel.save()
                                    if success {
                                        dismiss()
                                        onSaved()
                                    } else {
                                        showErrorAlert = true
                                    }
                                }
                            }
                            .disabled(!workShiftViewModel.canSave || workShiftViewModel.isSaving)
                        }
                    }
                }
            }
            .navigationTitle("予定の追加")
            .onAppear {
                let date = initialDate ?? Date()
                if eventViewModel == nil {
                    eventViewModel = CreateEventViewModel(initialDate: date)
                    eventViewModel?.loadTags()
                }
                if workShiftViewModel == nil {
                    workShiftViewModel = CreateWorkShiftViewModel(initialDate: date)
                    workShiftViewModel?.loadTags()
                    workShiftViewModel?.loadPayRates()
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsSheet()
            }
            .onChange(of: showSettingsSheet) { _, isShowing in
                if !isShowing {
                    eventViewModel?.loadTags()
                    workShiftViewModel?.loadTags()
                    workShiftViewModel?.loadPayRates()
                }
            }
            .alert("エラー", isPresented: $showErrorAlert) {
                Button("OK") {
                    showErrorAlert = false
                    eventViewModel?.errorMessage = nil
                    workShiftViewModel?.errorMessage = nil
                }
            } message: {
                Text(eventViewModel?.errorMessage ?? workShiftViewModel?.errorMessage ?? "")
            }
        }
    }
}

private struct CreateEventForm: View {
    @Bindable var viewModel: CreateEventViewModel

    var body: some View {
        Section("イベント") {
            TextField("タイトル", text: $viewModel.title)
            DatePicker("開始", selection: $viewModel.startAt, displayedComponents: [.date, .hourAndMinute])
            DatePicker("終了", selection: $viewModel.endAt, displayedComponents: [.date, .hourAndMinute])
            TextField("メモ", text: $viewModel.note, axis: .vertical)
                .lineLimit(3...6)
        }
        Section("タグ") {
            if viewModel.tags.isEmpty {
                Text("タグがありません。右上の設定から追加できます。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.tags) { tag in
                    Button {
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
    }
}

private struct CreateWorkShiftForm: View {
    @Bindable var viewModel: CreateWorkShiftViewModel

    var body: some View {
        Section("勤務時間") {
            DatePicker("開始", selection: $viewModel.startAt, displayedComponents: [.date, .hourAndMinute])
            DatePicker("終了", selection: $viewModel.endAt, displayedComponents: [.date, .hourAndMinute])
        }
        Section("給与") {
            Picker("種別", selection: $viewModel.payType) {
                Text("時給").tag(WorkPayType.hourly)
                Text("固定給").tag(WorkPayType.fixed)
            }
            .pickerStyle(.segmented)
            if viewModel.payType == .hourly {
                if viewModel.payRates.isEmpty {
                    Text("会社がありません。設定から追加して時給を設定できます。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.payRates) { rate in
                        Button {
                            viewModel.selectedPayRateId = viewModel.selectedPayRateId == rate.id ? nil : rate.id
                        } label: {
                            HStack {
                                Text(rate.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("¥\(NSDecimalNumber(decimal: rate.hourlyWage).stringValue)/時")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                                if viewModel.selectedPayRateId == rate.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
            if viewModel.payType == .fixed {
                TextField("金額", text: $viewModel.fixedPayText)
                    .keyboardType(.decimalPad)
            }
        }
        Section("タグ") {
            if viewModel.tags.isEmpty {
                Text("タグがありません。設定から追加できます。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.tags) { tag in
                    Button {
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
    }
}

#Preview {
    CreateItemSheet(initialDate: Date(), onSaved: {})
}
