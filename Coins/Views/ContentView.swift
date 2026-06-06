import Charts
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: GameStore
    @State private var selectedPage: AppPage = .main
    @State private var isDrawerOpen = false
    @State private var currentDate = Date.now
    @State private var displayedBalance = 0
    @State private var isAnimatingBalance = false
    @State private var rewardPresentation: RewardPresentation?

    private var style: ThemeStyle {
        themeStyle(for: store.snapshot.config.theme)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            FloatingCoinsBackground(style: style)

            VStack(spacing: 0) {
                AppTopBar(
                    page: selectedPage,
                    balance: displayedBalance,
                    style: style,
                    celebrationToken: store.celebrationToken
                ) {
                    openDrawer()
                }

                Divider()
                    .opacity(0.16)

                ZStack {
                    pageView

                    if let rewardPresentation {
                        RewardFlyOverlay(reward: rewardPresentation, style: style) {
                            self.rewardPresentation = nil
                        }
                        .transition(.opacity)
                        .zIndex(4)
                    }
                }
            }
            .overlay(alignment: .leading) {
                EdgeSwipeZone(isEnabled: !isDrawerOpen) {
                    openDrawer()
                }
            }

            drawerLayer
        }
        .onAppear {
            displayedBalance = store.snapshot.state.coinBalance
        }
        .onChange(of: store.snapshot.state.coinBalance) { _, newBalance in
            guard !isAnimatingBalance else { return }
            displayedBalance = newBalance
        }
        .task {
            currentDate = .now
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                currentDate = .now
            }
        }
    }

    @ViewBuilder
    private var pageView: some View {
        switch selectedPage {
        case .main:
            ActivitiesPage(currentDate: currentDate, style: style) { activity in
                complete(activity)
            }
        case .piggyBank:
            PiggyBankPage(style: style)
        case .tracking:
            TrackingPage(style: style)
        case .gameMaster:
            GameMasterView(showsCloseButton: false)
        }
    }

    private var drawerLayer: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width * 0.82, 320)

            ZStack(alignment: .leading) {
                if isDrawerOpen {
                    Color.black.opacity(0.22)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            closeDrawer()
                        }
                }

                HiddenSideNav(
                    selectedPage: selectedPage,
                    style: style,
                    width: width
                ) { page in
                    selectedPage = page
                    closeDrawer()
                }
                .offset(x: isDrawerOpen ? 0 : -width - 20)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.width < -48 {
                                closeDrawer()
                            }
                        }
                )
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isDrawerOpen)
        }
        .allowsHitTesting(isDrawerOpen)
        .zIndex(10)
    }

    private func complete(_ activity: ActivityDefinition) {
        let oldBalance = store.snapshot.state.coinBalance
        let result = store.complete(activity)
        let newBalance = store.snapshot.state.coinBalance

        guard !result.isDenied, result.totalCoinsAwarded > 0 else {
            displayedBalance = newBalance
            return
        }

        rewardPresentation = RewardPresentation(coins: result.totalCoinsAwarded)
        animateBalance(from: oldBalance, to: newBalance)
    }

    private func animateBalance(from oldBalance: Int, to newBalance: Int) {
        displayedBalance = oldBalance
        isAnimatingBalance = true

        let delta = newBalance - oldBalance
        guard delta != 0 else {
            displayedBalance = newBalance
            isAnimatingBalance = false
            return
        }

        let steps = min(max(abs(delta), 6), 24)
        let delay = UInt64(820_000_000 / max(steps, 1))

        Task { @MainActor in
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: delay)
                let progress = Double(step) / Double(steps)
                displayedBalance = oldBalance + Int((Double(delta) * progress).rounded())
            }
            displayedBalance = newBalance
            isAnimatingBalance = false
        }
    }

    private func openDrawer() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isDrawerOpen = true
        }
    }

    private func closeDrawer() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            isDrawerOpen = false
        }
    }
}

private enum AppPage: String, CaseIterable, Identifiable {
    case main
    case piggyBank
    case tracking
    case gameMaster

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main:
            return "Main"
        case .piggyBank:
            return "Piggy Bank"
        case .tracking:
            return "Tracking"
        case .gameMaster:
            return "Game Master"
        }
    }

    var symbol: String {
        switch self {
        case .main:
            return "checklist"
        case .piggyBank:
            return "banknote.fill"
        case .tracking:
            return "chart.xyaxis.line"
        case .gameMaster:
            return "slider.horizontal.3"
        }
    }
}

private struct RewardPresentation: Identifiable, Equatable {
    let id = UUID()
    let coins: Int
}

private struct AppTopBar: View {
    let page: AppPage
    let balance: Int
    let style: ThemeStyle
    let celebrationToken: Int
    let onMenu: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onMenu) {
                Image(systemName: "sidebar.leading")
                    .font(.title3.weight(.bold))
                    .frame(width: 42, height: 42)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open navigation")

            Text(page.title)
                .font(.headline.weight(.heavy))
                .lineLimit(1)

            Spacer(minLength: 12)

            HStack(spacing: 7) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(style.accent)
                    .symbolEffect(.bounce, value: celebrationToken)
                Text("\(balance)")
                    .font(.system(.title3, design: .rounded, weight: .black))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(balance == 1 ? "coin" : "coins")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.86), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(style.cardStroke, lineWidth: 1)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

private struct EdgeSwipeZone: View {
    let isEnabled: Bool
    let onOpen: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        guard isEnabled,
                              value.startLocation.x <= 32,
                              value.translation.width > 52,
                              abs(value.translation.height) < 90 else {
                            return
                        }
                        onOpen()
                    }
            )
            .allowsHitTesting(isEnabled)
    }
}

private struct HiddenSideNav: View {
    let selectedPage: AppPage
    let style: ThemeStyle
    let width: CGFloat
    let onSelect: (AppPage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Coins")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                Text("Choose a screen")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 22)

            VStack(spacing: 8) {
                ForEach(AppPage.allCases) { page in
                    Button {
                        onSelect(page)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: page.symbol)
                                .font(.headline.weight(.bold))
                                .frame(width: 26)
                                .foregroundStyle(selectedPage == page ? style.accent : .primary)
                            Text(page.title)
                                .font(.headline.weight(.semibold))
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(
                            selectedPage == page ? style.secondaryAccent.opacity(0.24) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Text("Swipe left to close")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 18)
        .frame(width: width, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(style.cardStroke)
                .frame(width: 1)
        }
        .ignoresSafeArea()
    }
}

private struct ActivitiesPage: View {
    @EnvironmentObject private var store: GameStore
    let currentDate: Date
    let style: ThemeStyle
    let onComplete: (ActivityDefinition) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let deniedReason = store.latestResult?.deniedReason {
                    Text(deniedReason)
                        .font(.headline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                ForEach(store.activities) { activity in
                    activityRow(for: activity)
                }
            }
            .padding(20)
            .padding(.bottom, 28)
        }
    }

    private func activityRow(for activity: ActivityDefinition) -> some View {
        let remainingLockout = store.remainingLockout(for: activity, at: currentDate)
        let stats = store.stats(for: activity, at: currentDate)
        let isDailyMaximumReached = activity.dailyMaximum > 0 && stats.completionsToday >= activity.dailyMaximum

        return Button {
            onComplete(activity)
        } label: {
            ActivityCard(
                activity: activity,
                stats: stats,
                remainingLockout: remainingLockout,
                isDailyMaximumReached: isDailyMaximumReached,
                style: style
            )
        }
        .buttonStyle(.plain)
        .disabled(remainingLockout > 0 || isDailyMaximumReached)
    }
}

private struct PiggyBankPage: View {
    @EnvironmentObject private var store: GameStore
    let style: ThemeStyle

    private var uncashedCoins: Int {
        store.snapshot.state.pendingCashOutCoins
    }

    private var pendingDollars: Double {
        Double(uncashedCoins) / store.snapshot.config.economy.coinsPerDollar
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    roundedCard

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Piggy Bank")
                                    .font(.system(.title, design: .rounded, weight: .heavy))
                                Text("Turn practice into bright little wins.")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "banknote.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(style.accent)
                                .symbolEffect(.bounce, value: store.celebrationToken)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(store.snapshot.state.coinBalance)")
                                .font(.system(size: 54, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text(store.snapshot.state.coinBalance == 1 ? "coin" : "coins")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            labelChip(title: "Streak \(store.snapshot.state.dailyStreak)d")
                            labelChip(title: String(format: "Cashed Out $%.2f", store.snapshot.state.cashedOutDollars))
                        }
                    }
                    .padding(22)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 12)], spacing: 12) {
                    statCard(title: "New Coins", value: "\(uncashedCoins)", note: String(format: "$%.2f pending", pendingDollars))
                    statCard(
                        title: "Cash Out Rate",
                        value: String(format: "%.0f", store.snapshot.config.economy.coinsPerDollar),
                        note: "coins per dollar"
                    )
                }

                Button {
                    store.cashOut()
                } label: {
                    Label("Cash Out New Coins", systemImage: "banknote")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(style.accent)

                if let cashOutMessage = store.cashOutMessage {
                    Text(cashOutMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(20)
            .padding(.bottom, 28)
        }
    }

    private func labelChip(title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(style.secondaryAccent.opacity(0.26), in: Capsule())
    }

    private func statCard(title: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title, design: .rounded, weight: .heavy))
                .monospacedDigit()
            Text(note)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var roundedCard: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(style.card)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(style.cardStroke, lineWidth: 1)
            )
    }
}

private struct TrackingPage: View {
    @EnvironmentObject private var store: GameStore
    let style: ThemeStyle

    private var dailySummaries: [DailyRewardSummary] {
        DailyRewardSummary.make(from: store.snapshot.state.rewardEvents)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 12)], spacing: 12) {
                    statCard(title: "Today", value: "\(store.snapshot.state.dailyCompletionCount)", note: "completions")
                    statCard(title: "Lifetime", value: "\(store.snapshot.state.lifetimeCoins)", note: "coins earned")
                }

                rewardsByDayChart
                cumulativeChart
                ledgerSection
            }
            .padding(20)
            .padding(.bottom, 28)
        }
    }

    private var rewardsByDayChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rewards By Day")
                .font(.title2.weight(.bold))

            if dailySummaries.isEmpty {
                emptyChartText
            } else {
                Chart(dailySummaries) { summary in
                    BarMark(
                        x: .value("Day", summary.date, unit: .day),
                        y: .value("Coins", summary.earnedCoins)
                    )
                    .foregroundStyle(style.accent)
                    .cornerRadius(5)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var cumulativeChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cumulative Coins")
                .font(.title2.weight(.bold))

            if dailySummaries.isEmpty {
                emptyChartText
            } else {
                Chart(dailySummaries) { summary in
                    LineMark(
                        x: .value("Day", summary.date, unit: .day),
                        y: .value("Coins", summary.cumulativeCoins)
                    )
                    .foregroundStyle(style.secondaryAccent)
                    .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("Day", summary.date, unit: .day),
                        y: .value("Coins", summary.cumulativeCoins)
                    )
                    .foregroundStyle(style.accent)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyChartText: some View {
        Text("Earn coins to start the graph.")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
    }

    private var ledgerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Rewards")
                .font(.title2.weight(.bold))

            if store.snapshot.state.rewardEvents.isEmpty {
                Text("No rewards yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ForEach(store.snapshot.state.rewardHistory.reversed().prefix(8)) { historyEntry in
                    let entry = historyEntry.event
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .fontWeight(.semibold)
                            Text(entry.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(entry.coins == 0 ? "0" : "\(entry.coins > 0 ? "+" : "")\(entry.coins)")
                                .fontWeight(.bold)
                                .foregroundStyle(entry.coins >= 0 ? style.accent : .red)
                            Text("\(historyEntry.balanceAfter) total")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private func statCard(title: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title, design: .rounded, weight: .heavy))
                .monospacedDigit()
            Text(note)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DailyRewardSummary: Identifiable {
    let dayKey: String
    let date: Date
    let earnedCoins: Int
    let cumulativeCoins: Int

    var id: String { dayKey }

    static func make(from rewardEvents: [RewardEvent], calendar: Calendar = .current) -> [DailyRewardSummary] {
        var rewardsByDay: [String: (date: Date, coins: Int)] = [:]

        for entry in rewardEvents where entry.coins > 0 {
            let date = calendar.startOfDay(for: entry.createdAt)
            let key = key(for: date, calendar: calendar)
            var bucket = rewardsByDay[key] ?? (date: date, coins: 0)
            bucket.coins += entry.coins
            rewardsByDay[key] = bucket
        }

        var cumulativeCoins = 0
        return rewardsByDay.values
            .sorted { $0.date < $1.date }
            .map { bucket in
                cumulativeCoins += bucket.coins
                return DailyRewardSummary(
                    dayKey: key(for: bucket.date, calendar: calendar),
                    date: bucket.date,
                    earnedCoins: bucket.coins,
                    cumulativeCoins: cumulativeCoins
                )
            }
    }

    private static func key(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

private struct RewardFlyOverlay: View {
    let reward: RewardPresentation
    let style: ThemeStyle
    let onFinished: () -> Void

    @State private var isFlying = false
    @State private var isFinished = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.white
                    .opacity(isFlying ? 0 : 0.92)

                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(style.secondaryAccent.opacity(0.28))
                            .frame(width: 82, height: 82)
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.system(size: 54, weight: .heavy))
                            .foregroundStyle(style.accent)
                    }

                    Text("Nice!")
                        .font(.system(.title, design: .rounded, weight: .black))

                    Text("You earned \(reward.coins) \(reward.coins == 1 ? "coin" : "coins")")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 26)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(style.secondaryAccent.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: style.accent.opacity(0.22), radius: 22, x: 0, y: 16)
                .scaleEffect(isFlying ? 0.22 : 1)
                .offset(y: isFlying ? -proxy.size.height * 0.5 - 12 : 0)
                .opacity(isFinished ? 0 : 1)

                CoinBurstView(trigger: reward.coins, style: style)
                    .opacity(isFlying ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .task(id: reward.id) {
            isFlying = false
            isFinished = false
            try? await Task.sleep(nanoseconds: 260_000_000)
            withAnimation(.easeInOut(duration: 0.58)) {
                isFlying = true
            }
            try? await Task.sleep(nanoseconds: 620_000_000)
            withAnimation(.easeOut(duration: 0.16)) {
                isFinished = true
            }
            try? await Task.sleep(nanoseconds: 180_000_000)
            onFinished()
        }
    }
}

private struct ActivityCard: View {
    let activity: ActivityDefinition
    let stats: ActivityStats
    let remainingLockout: Int
    let isDailyMaximumReached: Bool
    let style: ThemeStyle

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(style.secondaryAccent.opacity(0.24))
                    .frame(width: 54, height: 54)
                Image(systemName: activity.symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(style.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(activity.title)
                        .font(.headline)
                    Spacer()
                    Text("+\(activity.baseReward)")
                        .font(.headline)
                        .foregroundStyle(style.accent)
                }

                Text(activity.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Text(todayText)
                    Spacer()
                    if isDailyMaximumReached {
                        Text("Done for today")
                            .foregroundStyle(.secondary)
                    } else if remainingLockout > 0 {
                        Text("Ready in \(remainingLockout)s")
                            .foregroundStyle(.red)
                    } else {
                        Text("Tap to claim")
                            .foregroundStyle(style.accent)
                    }
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(isDailyMaximumReached ? 0.48 : 1)
    }

    private var todayText: String {
        if activity.dailyMaximum > 0 {
            return "Today \(stats.completionsToday)/\(activity.dailyMaximum)"
        }
        return "Today \(stats.completionsToday)x"
    }
}
