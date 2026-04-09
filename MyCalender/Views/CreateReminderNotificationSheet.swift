import SwiftUI

struct CreateReminderNotificationSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: CreateReminderNotificationViewModel
    @State private var showErrorAlert = false
    @State private var isPresentingPendingRemindersSheet = false

    init(defaultDate: Date) {
        _viewModel = State(initialValue: CreateReminderNotificationViewModel(defaultDate: defaultDate))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "通知する日時",
                        selection: Binding(
                            get: { viewModel.notifyAt },
                            set: { viewModel.notifyAt = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    TextField(
                        "タイトル",
                        text: Binding(
                            get: { viewModel.title },
                            set: { viewModel.title = $0 }
                        )
                    )

                    TextField(
                        "内容（任意）",
                        text: Binding(
                            get: { viewModel.body },
                            set: { viewModel.body = $0 }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(2...5)

                    Toggle(
                        "予定にも追加する",
                        isOn: Binding(
                            get: { viewModel.shouldAlsoAddToSchedule },
                            set: { viewModel.shouldAlsoAddToSchedule = $0 }
                        )
                    )
                }

                Section("タグ") {
                    if viewModel.tags.isEmpty {
                        Text("タグがありません。未選択のままでも登録できます。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.tags) { tag in
                            Button {
                                FeedBack().feedback(.light)
                                if viewModel.selectedTagId == tag.id {
                                    viewModel.selectedTagId = nil
                                } else {
                                    viewModel.selectedTagId = tag.id
                                }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color.from(hex: tag.colorHex))
                                        .frame(width: 16, height: 16)
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if viewModel.selectedTagId == tag.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("通知を追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        FeedBack().feedback(.light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            FeedBack().feedback(.light)
                            isPresentingPendingRemindersSheet = true
                        } label: {
                            Image(systemName: "clock")
                        }
                        .accessibilityLabel("未通知の一覧")

                        Button("保存") {
                            FeedBack().feedback(.medium)
                            Task {
                                let success = await viewModel.saveReminder()
                                if success {
                                    dismiss()
                                } else {
                                    showErrorAlert = true
                                }
                            }
                        }
                        .disabled(!viewModel.canSave || viewModel.isSaving)
                    }
                }
            }
            .onAppear {
                viewModel.loadTags()
                Task {
                    do {
                        try await viewModel.loadPendingRapidEvents()
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                }
            }
            .sheet(isPresented: $isPresentingPendingRemindersSheet) {
                PendingRapidEventsSheet(
                    viewModel: viewModel,
                    rapidEvents: viewModel.pendingRapidEvents,
                    isLoading: viewModel.isLoadingPendingRapidEvents,
                    onError: { showErrorAlert = true }
                )
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
        }
    }
}

private struct PendingRapidEventsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: CreateReminderNotificationViewModel
    let rapidEvents: [RapidEvent]
    let isLoading: Bool
    let onError: () -> Void

    @State private var selectedRapidEvent: RapidEvent?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if rapidEvents.isEmpty {
                    ContentUnavailableView("未通知の通知はありません", systemImage: "clock")
                } else {
                    List(rapidEvents) { item in
                        Button {
                            FeedBack().feedback(.light)
                            selectedRapidEvent = item
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(formatted(date: item.notifyAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deletePendingRapidEvent(item)
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("未通知の通知一覧")
            .sheet(item: $selectedRapidEvent) { item in
                EditRapidEventSheet(
                    rapidEvent: item,
                    tags: viewModel.tags,
                    onSave: { notifyAt, title, body, selectedTagId in
                        let success = await viewModel.updatePendingRapidEvent(
                            item,
                            notifyAt: notifyAt,
                            title: title,
                            body: body,
                            selectedTagId: selectedTagId
                        )
                        if !success {
                            onError()
                        }
                        return success
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        FeedBack().feedback(.light)
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatted(date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

private struct EditRapidEventSheet: View {
    @Environment(\.dismiss) private var dismiss

    let rapidEvent: RapidEvent
    let tags: [Tag]
    let onSave: (Date, String, String, TagID?) async -> Bool

    @State private var notifyAt: Date
    @State private var title: String
    @State private var messageBody: String
    @State private var selectedTagId: TagID?
    @State private var isSaving = false
    @State private var showErrorAlert = false

    init(
        rapidEvent: RapidEvent,
        tags: [Tag],
        onSave: @escaping (Date, String, String, TagID?) async -> Bool
    ) {
        self.rapidEvent = rapidEvent
        self.tags = tags
        self.onSave = onSave
        _notifyAt = State(initialValue: rapidEvent.notifyAt)
        _title = State(initialValue: rapidEvent.title)
        _messageBody = State(initialValue: rapidEvent.body)
        _selectedTagId = State(initialValue: rapidEvent.tagId)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && notifyAt > Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("通知する日時", selection: $notifyAt, displayedComponents: [.date, .hourAndMinute])
                    TextField("タイトル", text: $title)
                    TextField("内容", text: $messageBody, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("タグ") {
                    if tags.isEmpty {
                        Text("タグがありません。未選択のままでも保存できます。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(tags) { tag in
                            Button {
                                FeedBack().feedback(.light)
                                selectedTagId = (selectedTagId == tag.id) ? nil : tag.id
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color.from(hex: tag.colorHex))
                                        .frame(width: 16, height: 16)
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedTagId == tag.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("通知を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        Task {
                            isSaving = true
                            let success = await onSave(notifyAt, title, messageBody, selectedTagId)
                            isSaving = false
                            if success {
                                dismiss()
                            } else {
                                showErrorAlert = true
                            }
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .alert("保存に失敗しました", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}
