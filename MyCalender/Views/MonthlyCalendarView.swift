import SwiftUI

/// 縦スクロールで月が続くカレンダー。予定のある日の下にタグ色の短いバーを並べる。
struct MonthlyCalendarView: View {
    private let viewModel: MonthCalendarViewModel

    var anchorMonth: Date
    @Binding var selectedDate: Date
    var events: [Event]
    var workShifts: [WorkShift]
    var tags: [Tag]
    var isLoading: Bool
    var onSelectDay: (Date) -> Void
    var onRefresh: () async -> Void

    init(
        viewModel: MonthCalendarViewModel,
        anchorMonth: Date,
        selectedDate: Binding<Date>,
        events: [Event],
        workShifts: [WorkShift],
        tags: [Tag],
        isLoading: Bool,
        onSelectDay: @escaping (Date) -> Void,
        onRefresh: @escaping () async -> Void
    ) {
        self.viewModel = viewModel
        self.anchorMonth = anchorMonth
        self._selectedDate = selectedDate
        self.events = events
        self.workShifts = workShifts
        self.tags = tags
        self.isLoading = isLoading
        self.onSelectDay = onSelectDay
        self.onRefresh = onRefresh
    }

    private var monthStarts: [Date] {
        viewModel.monthStarts(anchorMonth: anchorMonth)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(monthStarts, id: \.self) { monthStart in
                        monthSection(monthStart: monthStart)
                            .id(viewModel.monthId(for: monthStart))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 72)
            }
            .refreshable { await onRefresh() }
            .overlay {
                if isLoading, events.isEmpty, workShifts.isEmpty {
                    ProgressView()
                        .scaleEffect(1.2)
                }
            }
            .overlay(alignment: .bottomLeading) {
                todayButton {
                    let today = viewModel.todayStartOfDay()
                    selectedDate = today
                    FeedBack().feedback(.medium)
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(viewModel.monthId(for: today.startOfMonth()), anchor: .top)
                    }
                }
                .padding(.leading, 16)
                .padding(.bottom, 8)
            }
            .onAppear {
                let initial = anchorMonth.startOfMonth()
                let id = viewModel.monthId(for: initial)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    proxy.scrollTo(id, anchor: .top)
                }
            }
            .onChange(of: anchorMonth) { _, newValue in
                let m = newValue.startOfMonth()
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(viewModel.monthId(for: m), anchor: .top)
                }
            }
        }
    }

    private func monthSection(monthStart: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.monthTitle(for: monthStart))
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(viewModel.weekdayLabels[i])
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let weeks = viewModel.weeks(for: monthStart)
            VStack(spacing: 0) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    weekRow(week: week)
                    Rectangle()
                        .fill(Color(.separator).opacity(0.35))
                        .frame(height: 0.5)
                }
            }
        }
    }

    private func weekRow(week: [Date?]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<7, id: \.self) { ix in
                if let day = week[ix] {
                    dayCell(day: day)
                        .frame(maxWidth: .infinity)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func dayCell(day: Date) -> some View {
        let state = viewModel.dayCellState(
            for: day,
            selectedDate: selectedDate,
            events: events,
            workShifts: workShifts,
            tags: tags
        )
        let dayStart = day.startOfDay()

        return Button {
            FeedBack().feedback(.medium)
            selectedDate = dayStart
            onSelectDay(dayStart)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if state.isToday {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 32, height: 32)
                    } else if state.isSelected {
                        Circle()
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                            .frame(width: 32, height: 32)
                    }
                    Text("\(state.dayNumber)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(
                            state.isToday
                                ? Color.white
                                : (state.isWeekend ? Color.secondary : Color.primary)
                        )
                }
                .frame(height: 34)

                HStack(spacing: 2) {
                    ForEach(Array(state.barColorHexes.prefix(4).enumerated()), id: \.offset) { _, hex in
                        Capsule()
                            .fill(barFillColor(hex: hex))
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: state.barColorHexes.isEmpty ? 0 : 3)
                .opacity(state.barColorHexes.isEmpty ? 0 : 1)
            }
            .frame(minHeight: 52)
        }
        .buttonStyle(.plain)
    }

    private func barFillColor(hex: String) -> Color {
        if hex == Constants.defaultBoxColorSentinel {
            return Color(.systemGray5).opacity(0.5)
        }
        return Color.from(hex: hex).opacity(0.85)
    }

    private func todayButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "eject.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MonthlyCalendarView(
        viewModel: MonthCalendarViewModel(),
        anchorMonth: Date(),
        selectedDate: .constant(Date()),
        events: [],
        workShifts: [],
        tags: [],
        isLoading: false,
        onSelectDay: { _ in },
        onRefresh: {}
    )
}
