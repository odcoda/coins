import SwiftUI

struct HistoryEditorView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    @State private var endDate = Date.now
    @State private var selectedDay: ActivityHistoryDay?

    private let gridSpacing: CGFloat = 6

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        return calendar
    }

    private var days: [ActivityHistoryDay] {
        store.snapshot.state.activityCountsByDay(endingAt: endDate, days: 30, calendar: calendar)
    }

    private var gridDays: [Date?] {
        guard let firstDay = days.first?.date, let lastDay = days.last?.date else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -leadingBlanks, to: firstDay) ?? firstDay
        let lastWeekday = calendar.component(.weekday, from: lastDay)
        let trailingBlanks = (7 - ((lastWeekday - calendar.firstWeekday + 7) % 7) - 1)
        let end = calendar.date(byAdding: .day, value: trailingBlanks, to: lastDay) ?? lastDay
        let dayCount = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1

        return (0..<dayCount).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            let isInRange = days.contains { calendar.isDate($0.date, inSameDayAs: date) }
            return isInRange ? date : nil
        }
    }

    private var maxCount: Int {
        max(days.map(\.totalCount).max() ?? 0, 1)
    }

    private var daysByStartOfDay: [Date: ActivityHistoryDay] {
        Dictionary(uniqueKeysWithValues: days.map { (calendar.startOfDay(for: $0.date), $0) })
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                DatePicker(
                    "Show 30 days ending",
                    selection: $endDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)

                GeometryReader { proxy in
                    let cellSize = floor((proxy.size.width - gridSpacing * 6) / 7)
                    let columns = Array(
                        repeating: GridItem(.fixed(cellSize), spacing: gridSpacing),
                        count: 7
                    )

                    VStack(spacing: gridSpacing) {
                        weekdayHeader(columns: columns)

                        LazyVGrid(columns: columns, spacing: gridSpacing) {
                            ForEach(Array(gridDays.enumerated()), id: \.offset) { _, date in
                                if let date {
                                    dayCell(for: date, size: cellSize)
                                } else {
                                    Color.clear
                                        .frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle("History Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedDay) { day in
                DayActivitySheet(
                    day: day,
                    activities: store.snapshot.config.activities
                )
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func weekdayHeader(columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(shortWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var shortWeekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let firstIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    private func dayCell(for date: Date, size: CGFloat) -> some View {
        let day = daysByStartOfDay[calendar.startOfDay(for: date)] ?? ActivityHistoryDay(date: date, countsByActivityID: [:])
        let intensity = Double(day.totalCount) / Double(maxCount)

        return Button {
            selectedDay = day
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(day.totalCount > 0 ? .white : .secondary)
                .frame(width: size, height: size)
            .background(dayColor(for: intensity, hasActivity: day.totalCount > 0), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(day.totalCount > 0 ? 0 : 0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day))
    }

    private func dayColor(for intensity: Double, hasActivity: Bool) -> Color {
        guard hasActivity else {
            return Color(.secondarySystemBackground)
        }
        return Color.green.opacity(0.28 + min(max(intensity, 0), 1) * 0.62)
    }

    private func accessibilityLabel(for day: ActivityHistoryDay) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        if day.totalCount == 0 {
            return "\(formatter.string(from: day.date)), no activities"
        }
        return "\(formatter.string(from: day.date)), \(day.totalCount) activities"
    }

}

private struct DayActivitySheet: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    let day: ActivityHistoryDay
    let activities: [ActivityDefinition]

    @State private var draftCounts: [String: Int] = [:]
    @State private var originalCounts: [String: Int] = [:]
    @State private var didSave = false

    private let countOptions = Array(0...50)

    private var dateText: String {
        day.date.formatted(date: .complete, time: .omitted)
    }

    private var hasChanges: Bool {
        activities.contains { activity in
            draftCounts[activity.id, default: 0] != originalCounts[activity.id, default: 0]
        }
    }

    private var balanceDelta: Int {
        HistoryRewardEstimator.delta(
            from: originalCounts,
            to: draftCounts,
            activities: activities
        )
    }

    private var balanceDeltaText: String {
        if balanceDelta > 0 {
            return "+\(balanceDelta)"
        }
        return "\(balanceDelta)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(dateText) {
                    ForEach(activities) { activity in
                        HStack(spacing: 12) {
                            Image(systemName: activity.symbol)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.orange)
                                .frame(width: 32, height: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.title)
                                    .font(.headline)
                                Text(diffText(for: activity.id))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(diffColor(for: activity.id))
                            }

                            Spacer()

                            Picker("Count", selection: countBinding(for: activity.id)) {
                                ForEach(countOptions, id: \.self) { count in
                                    Text("\(count)").tag(count)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }
                }

                Section {
                    Button {
                        saveChanges()
                    } label: {
                        Label("Save Changes", systemImage: "square.and.arrow.down.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .fontWeight(.bold)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    if hasChanges {
                        Button {
                            saveChanges(adjustBalance: true)
                        } label: {
                            Label(
                                "Save Changes and Adjust Balance (\(balanceDeltaText))",
                                systemImage: "bitcoinsign.circle.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .fontWeight(.bold)
                        .buttonStyle(.bordered)
                        .tint(balanceDelta >= 0 ? .green : .red)
                    }

                    if didSave {
                        Label("History saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Day History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCounts()
            }
        }
    }

    private func countBinding(for activityID: String) -> Binding<Int> {
        Binding {
            draftCounts[activityID, default: 0]
        } set: { newValue in
            draftCounts[activityID] = newValue
            didSave = false
        }
    }

    private func diffText(for activityID: String) -> String {
        let diff = draftCounts[activityID, default: 0] - originalCounts[activityID, default: 0]
        if diff == 0 {
            return "No change"
        }
        return diff > 0 ? "+\(diff)" : "\(diff)"
    }

    private func diffColor(for activityID: String) -> Color {
        let diff = draftCounts[activityID, default: 0] - originalCounts[activityID, default: 0]
        if diff > 0 {
            return .green
        }
        if diff < 0 {
            return .red
        }
        return .secondary
    }

    private func loadCounts() {
        originalCounts = store.snapshot.state.activityCounts(on: day.date)
        draftCounts = originalCounts
        for activity in activities where draftCounts[activity.id] == nil {
            draftCounts[activity.id] = 0
        }
    }

    private func saveChanges(adjustBalance: Bool = false) {
        store.rewriteActivityHistory(
            on: day.date,
            countsByActivityID: draftCounts,
            balanceDelta: adjustBalance ? balanceDelta : 0
        )
        originalCounts = store.snapshot.state.activityCounts(on: day.date)
        draftCounts = originalCounts
        didSave = true
    }
}
