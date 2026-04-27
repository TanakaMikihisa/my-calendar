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
                        .accessibilityLabel("通知一覧")

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
                        try await viewModel.loadRapidEventLists()
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                }
            }
            .sheet(isPresented: $isPresentingPendingRemindersSheet) {
                PendingRapidEventsSheet(
                    viewModel: viewModel,
                    isLoading: viewModel.isLoadingRapidEventLists,
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

private enum RapidEventsListTab: String, CaseIterable, Identifiable, Hashable {
    case pending
    case past

    var id: String { rawValue }

    /// セグメント用（長い文は2行化され幅を食うため短く。ナビ上は `accessibility` で補足）
    var segmentTitle: String {
        switch self {
        case .pending: "これから"
        case .past: "これまで"
        }
    }
}

private struct PendingRapidEventsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: CreateReminderNotificationViewModel
    let isLoading: Bool
    let onError: () -> Void

    @State private var listTab: RapidEventsListTab = .pending
    /// 編集画面へのプッシュ。`navigationDestination(item:)` はタブ＋`List` の組み合わせで遷移しないことがあるため `NavigationPath` を使う。
    @State private var detailNavigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $detailNavigationPath) {
            VStack(spacing: 0) {
                Picker("表示", selection: $listTab) {
                    ForEach(RapidEventsListTab.allCases) { tab in
                        Text(tab.segmentTitle)
                            .tag(tab)
                    }
                }
                .accessibilityValue(listTab == .pending ? "これからの通知一覧を表示中" : "これまでの通知一覧を表示中")
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

                Group {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else {
                        switch listTab {
                        case .pending: pendingList
                        case .past: pastList
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("通知の一覧")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: listTab) { _, _ in
                detailNavigationPath = NavigationPath()
            }
            .navigationDestination(for: RapidEvent.self) { item in
                EditRapidEventSheet(
                    rapidEvent: item,
                    tags: viewModel.tags,
                    onSave: { notifyAt, title, body, selectedTagId in
                        let success = await viewModel.saveRapidEventEdit(
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

    @ViewBuilder
    private var pendingList: some View {
        if viewModel.pendingRapidEvents.isEmpty {
            ContentUnavailableView("未通知の通知はありません", systemImage: "clock")
        } else {
            List(viewModel.pendingRapidEvents) { item in
                rapidEventRow(item: item)
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var pastList: some View {
        if viewModel.pastRapidEvents.isEmpty {
            ContentUnavailableView("通知済みの履歴はありません", systemImage: "checkmark.circle")
        } else {
            List(viewModel.pastRapidEvents) { item in
                rapidEventRow(item: item)
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func rapidEventRow(item: RapidEvent) -> some View {
        Button {
            FeedBack().feedback(.light)
            detailNavigationPath.append(item)
        } label: {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(formatted(date: item.notifyAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
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
    }

    var body: some View {
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
        .navigationBarBackButtonHidden(true)
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
