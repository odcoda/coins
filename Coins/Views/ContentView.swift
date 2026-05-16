import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: GameStore
    @State private var isShowingMaster = false
    @State private var currentDate = Date.now

    private var style: ThemeStyle {
        themeStyle(for: store.snapshot.config.theme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FloatingCoinsBackground(style: style)

                ScrollView {
                    VStack(spacing: 18) {
                        headerCard

                        if let latestResult = store.latestResult {
                            resultBanner(for: latestResult)
                        }

                        activitiesSection
                        progressSection
                        achievementsSection
                        ledgerSection
                        footerSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Coins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingMaster = true
                    } label: {
                        Label("Game Master", systemImage: "gearshape.fill")
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                currentDate = .now
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    currentDate = .now
                }
            }
        }
        .sheet(isPresented: $isShowingMaster) {
            GameMasterView()
                .environmentObject(store)
        }
    }

    private var headerCard: some View {
        ZStack {
            roundedCard

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Piggy Bank")
                            .font(.system(.title, design: .rounded, weight: .heavy))
                        Text("Turn practice into bright little wins.")
                            .font(.subheadline)
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
                        .contentTransition(.numericText())
                    Text("coins")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    labelChip(title: "Streak \(store.snapshot.state.dailyStreak)d")
                    labelChip(title: String(format: "Cashed Out $%.2f", store.snapshot.state.cashedOutDollars))
                }
            }
            .padding(22)

            CoinBurstView(trigger: store.celebrationToken, style: style)
        }
    }

    private func resultBanner(for result: CompletionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let deniedReason = result.deniedReason {
                Text(deniedReason)
                    .font(.headline)
                    .foregroundStyle(.red)
            } else {
                Text("+\(result.totalCoinsAwarded) coins")
                    .font(.headline)
                    .foregroundStyle(style.accent)

                ForEach(result.events) { event in
                    HStack(alignment: .top) {
                        Text(event.title)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(event.coins == 0 ? "Sync" : "+\(event.coins)")
                            .foregroundStyle(style.accent)
                    }
                    Text(event.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activities")
                .font(.title2.weight(.bold))

            ForEach(store.activities) { activity in
                activityRow(for: activity)
            }
        }
    }

    private func activityRow(for activity: Activity) -> some View {
        let remainingLockout = store.remainingLockout(for: activity, at: currentDate)

        return Button {
            store.complete(activity)
        } label: {
            ActivityCard(
                activity: activity,
                progress: store.progress(for: activity),
                remainingLockout: remainingLockout,
                style: style
            )
        }
        .buttonStyle(.plain)
        .disabled(remainingLockout > 0)
    }

    private var progressSection: some View {
        HStack(spacing: 12) {
            statCard(title: "Today", value: "\(store.snapshot.state.dailyCompletionCount)", note: "completions")
            statCard(title: "Lifetime", value: "\(store.snapshot.state.lifetimeCoins)", note: "coins earned")
            statCard(title: "Unlocked", value: "\(store.snapshot.state.unlockedAchievementIDs.count)", note: "achievements")
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.title2.weight(.bold))

            if store.unlockedAchievements.isEmpty {
                Text("No trophies yet. Keep the streak going.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.unlockedAchievements) { achievement in
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(style.accent)
                        VStack(alignment: .leading) {
                            Text(achievement.title)
                                .fontWeight(.semibold)
                            Text(achievement.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("+\(achievement.rewardCoins)")
                            .foregroundStyle(style.accent)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
        }
    }

    private var ledgerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Rewards")
                .font(.title2.weight(.bold))

            ForEach(store.snapshot.state.ledger.prefix(6)) { entry in
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
                            .foregroundStyle(entry.coins >= 0 ? style.accent : .red)
                        Text("\(entry.balanceAfter) total")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private var footerSection: some View {
        VStack(spacing: 10) {
            Button {
                store.cashOut()
            } label: {
                Text("Cash Out New Coins")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(style.accent)

            if let cashOutMessage = store.cashOutMessage {
                Text(cashOutMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
            Text(note)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func labelChip(title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(style.secondaryAccent.opacity(0.26), in: Capsule())
    }

    private var roundedCard: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(style.card)
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(style.cardStroke, lineWidth: 1)
            )
    }
}

private struct ActivityCard: View {
    let activity: Activity
    let progress: ActivityProgress
    let remainingLockout: Int
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
                    Text("Today \(progress.completionsToday)x")
                    Spacer()
                    if remainingLockout > 0 {
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
