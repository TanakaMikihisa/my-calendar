import SwiftUI

struct EditEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    var event: Event
    var tags: [Tag]
    var onSaved: () -> Void
    /// 削除成功時に呼ぶ（詳細画面を閉じる場合に指定）。未指定時は onSaved を呼ぶ
    var onDeleted: (() -> Void)? = nil

    @State private var viewModel: EditEventViewModel
    @State private var showErrorAlert = false
    @State private var showDeleteConfirm = false

    init(event: Event, tags: [Tag], onSaved: @escaping () -> Void, onDeleted: (() -> Void)? = nil) {
        self.event = event
        self.tags = tags
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _viewModel = State(initialValue: EditEventViewModel(event: event))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("イベント") {
                    TextField("タイトル", text: $viewModel.title)
                    DatePicker("開始", selection: $viewModel.startAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("終了", selection: $viewModel.endAt, displayedComponents: [.date, .hourAndMinute])
                    TextField("メモ（任意）", text: $viewModel.note, axis: .vertical)
                        .lineLimit(3...6)
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
                    Button("予定を削除", role: .destructive) {
                        FeedBack().feedback(.heavy)
                        showDeleteConfirm = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("イベントを編集")
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
            .alert("予定を削除しますか？", isPresented: $showDeleteConfirm) {
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
    let end = cal.date(bySettingHour: 10, minute: 30, second: 0, of: today)!
    let event = Event(id: "pe1", type: .normal, title: "編集プレビュー", startAt: start, endAt: end, note: "メモ", tagIds: ["pt1"], isActive: true, createdAt: .distantPast, updatedAt: .distantPast)
    let tags = [Tag(id: "pt1", name: "仕事", colorHex: "#34C759", isActive: true, createdAt: .distantPast, updatedAt: .distantPast)]
    return EditEventSheet(event: event, tags: tags) {}
}
