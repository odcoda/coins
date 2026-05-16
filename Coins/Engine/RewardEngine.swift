import Foundation

enum RewardEngine {
    static func complete(
        activityID: String,
        snapshot: inout GameSnapshot,
        now: Date = .now,
        roll: Double? = nil,
        chestCoins: Int? = nil,
        calendar: Calendar = .current
    ) -> CompletionResult {
        guard let activity = snapshot.config.activities.first(where: { $0.id == activityID }) else {
            return CompletionResult(events: [], deniedReason: "That activity no longer exists.", speechText: "That activity no longer exists.")
        }

        normalizeDay(on: &snapshot.state, now: now, calendar: calendar)
        let todayKey = dayKey(for: now, calendar: calendar)
        var progress = snapshot.state.activityProgress[activityID] ?? ActivityProgress()

        if let lastCompletedAt = progress.lastCompletedAt {
            let elapsed = now.timeIntervalSince(lastCompletedAt)
            if elapsed < Double(activity.lockoutSeconds) {
                snapshot.state.suspiciousTapCount += 1
                let remaining = Int(ceil(Double(activity.lockoutSeconds) - elapsed))
                let denial = "Lockout active for \(remaining)s."
                return CompletionResult(events: [], deniedReason: denial, speechText: denial)
            }
        }

        var events: [RewardEvent] = []
        let firstCompletionToday = snapshot.state.dailyCompletionCount == 0

        progress.totalCompletions += 1
        progress.completionsToday += 1
        progress.lastCompletedAt = now
        progress.lastCompletedDayKey = todayKey
        snapshot.state.activityProgress[activityID] = progress

        if firstCompletionToday {
            if let lastActiveDayKey = snapshot.state.lastActiveDayKey {
                let gap = dayDistance(from: lastActiveDayKey, to: todayKey, calendar: calendar)
                snapshot.state.dailyStreak = gap == 1 ? max(snapshot.state.dailyStreak, 0) + 1 : 1
            } else {
                snapshot.state.dailyStreak = 1
            }
            snapshot.state.lastActiveDayKey = todayKey
        }

        snapshot.state.currentDayKey = todayKey
        snapshot.state.dailyCompletionCount += 1

        let structured = RewardEvent(
            id: UUID(),
            title: activity.title,
            detail: activity.detail,
            coins: activity.baseReward,
            kind: .structured
        )
        apply(event: structured, to: &snapshot.state, now: now)
        events.append(structured)

        for milestone in snapshot.config.comboMilestones where snapshot.state.dailyCompletionCount == milestone.count {
            let combo = RewardEvent(
                id: UUID(),
                title: milestone.title,
                detail: "You hit \(milestone.count) total completions today.",
                coins: milestone.bonusCoins,
                kind: .combo
            )
            apply(event: combo, to: &snapshot.state, now: now)
            events.append(combo)
        }

        if firstCompletionToday {
            for milestone in snapshot.config.dailyStreakMilestones where snapshot.state.dailyStreak == milestone.days {
                let streak = RewardEvent(
                    id: UUID(),
                    title: milestone.title,
                    detail: "Day \(milestone.days) in a row.",
                    coins: milestone.bonusCoins,
                    kind: .dailyStreak
                )
                apply(event: streak, to: &snapshot.state, now: now)
                events.append(streak)
            }
        }

        if let chest = treasureChestEvent(snapshot: snapshot, now: now, roll: roll, chestCoins: chestCoins) {
            apply(event: chest, to: &snapshot.state, now: now)
            events.append(chest)
        }

        let unlocked = unlockAchievements(snapshot: &snapshot, activityID: activityID, now: now)
        events.append(contentsOf: unlocked)

        let speechText = events.map(\.title).joined(separator: ". ")
        return CompletionResult(events: events, deniedReason: nil, speechText: speechText)
    }

    static func cashOut(snapshot: inout GameSnapshot, now: Date = .now) -> RewardEvent? {
        let uncashedCoins = max(snapshot.state.coinBalance - snapshot.state.cashedOutCoinsWatermark, 0)
        guard uncashedCoins > 0 else {
            return nil
        }

        let dollars = Double(uncashedCoins) / snapshot.config.economy.coinsPerDollar
        snapshot.state.cashedOutCoinsWatermark = snapshot.state.coinBalance
        snapshot.state.cashedOutDollars += dollars

        let event = RewardEvent(
            id: UUID(),
            title: "Cash Out",
            detail: String(format: "Converted %d new coins into $%.2f earned.", uncashedCoins, dollars),
            coins: 0,
            kind: .cashOut
        )
        snapshot.state.ledger.insert(
            LedgerEntry(
                id: UUID(),
                createdAt: now,
                title: event.title,
                detail: event.detail,
                coins: 0,
                balanceAfter: snapshot.state.coinBalance,
                kind: .cashOut
            ),
            at: 0
        )
        return event
    }

    static func adjustCoins(snapshot: inout GameSnapshot, delta: Int, reason: String, now: Date = .now) -> RewardEvent? {
        guard delta != 0 else {
            return nil
        }

        snapshot.state.coinBalance = max(snapshot.state.coinBalance + delta, 0)
        if delta > 0 {
            snapshot.state.lifetimeCoins += delta
        } else {
            snapshot.state.cashedOutCoinsWatermark = min(snapshot.state.cashedOutCoinsWatermark, snapshot.state.coinBalance)
        }

        let event = RewardEvent(
            id: UUID(),
            title: delta > 0 ? "Manual Bonus" : "Manual Rewind",
            detail: reason,
            coins: delta,
            kind: .adjustment
        )
        snapshot.state.ledger.insert(
            LedgerEntry(
                id: UUID(),
                createdAt: now,
                title: event.title,
                detail: event.detail,
                coins: delta,
                balanceAfter: snapshot.state.coinBalance,
                kind: .adjustment
            ),
            at: 0
        )
        return event
    }

    static func remainingLockout(for activity: Activity, snapshot: GameSnapshot, now: Date = .now) -> TimeInterval {
        guard let progress = snapshot.state.activityProgress[activity.id],
              let lastCompletedAt = progress.lastCompletedAt else {
            return 0
        }
        return max(Double(activity.lockoutSeconds) - now.timeIntervalSince(lastCompletedAt), 0)
    }

    private static func treasureChestEvent(
        snapshot: GameSnapshot,
        now: Date,
        roll: Double?,
        chestCoins: Int?
    ) -> RewardEvent? {
        let config = snapshot.config.treasureChest
        guard config.isEnabled else { return nil }
        guard snapshot.state.dailyStreak >= config.minDailyStreak else { return nil }
        guard snapshot.state.dailyCompletionCount >= config.minDailyCompletions else { return nil }

        let draw = roll ?? Double.random(in: 0...1)
        guard draw <= config.chance else { return nil }

        let reward = chestCoins ?? Int.random(in: config.minCoins...config.maxCoins)
        return RewardEvent(
            id: UUID(),
            title: "Treasure Chest",
            detail: "A surprise reward dropped.",
            coins: reward,
            kind: .treasureChest
        )
    }

    private static func unlockAchievements(
        snapshot: inout GameSnapshot,
        activityID: String,
        now: Date
    ) -> [RewardEvent] {
        var unlocked: [RewardEvent] = []
        let totalCompletions = snapshot.state.activityProgress.values.reduce(0) { $0 + $1.totalCompletions }
        let activityCompletions = snapshot.state.activityProgress[activityID]?.totalCompletions ?? 0

        for achievement in snapshot.config.achievements where !snapshot.state.unlockedAchievementIDs.contains(achievement.id) {
            let metricValue: Int
            switch achievement.metric {
            case .totalCompletions:
                metricValue = totalCompletions
            case .lifetimeCoins:
                metricValue = snapshot.state.lifetimeCoins
            case .dailyStreak:
                metricValue = snapshot.state.dailyStreak
            case .activityCompletions:
                metricValue = achievement.activityID == activityID ? activityCompletions : 0
            }

            guard metricValue >= achievement.threshold else { continue }
            snapshot.state.unlockedAchievementIDs.insert(achievement.id)

            let event = RewardEvent(
                id: UUID(),
                title: achievement.title,
                detail: achievement.detail,
                coins: achievement.rewardCoins,
                kind: .achievement
            )
            apply(event: event, to: &snapshot.state, now: now)
            unlocked.append(event)
        }

        return unlocked
    }

    private static func apply(event: RewardEvent, to state: inout GameState, now: Date) {
        state.coinBalance += event.coins
        if event.coins > 0 {
            state.lifetimeCoins += event.coins
        }

        state.ledger.insert(
            LedgerEntry(
                id: UUID(),
                createdAt: now,
                title: event.title,
                detail: event.detail,
                coins: event.coins,
                balanceAfter: state.coinBalance,
                kind: event.kind
            ),
            at: 0
        )
    }

    private static func normalizeDay(on state: inout GameState, now: Date, calendar: Calendar) {
        let todayKey = dayKey(for: now, calendar: calendar)
        guard state.currentDayKey != todayKey else { return }

        if let currentDayKey = state.currentDayKey {
            let gap = dayDistance(from: currentDayKey, to: todayKey, calendar: calendar)
            if gap > 1 {
                state.dailyStreak = 0
            }
        }

        state.currentDayKey = todayKey
        state.dailyCompletionCount = 0
        for key in state.activityProgress.keys {
            guard var progress = state.activityProgress[key] else { continue }
            progress.completionsToday = 0
            state.activityProgress[key] = progress
        }
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static func dayDistance(from lhs: String, to rhs: String, calendar: Calendar) -> Int {
        guard let lhsDate = dayFormatter.date(from: lhs),
              let rhsDate = dayFormatter.date(from: rhs) else {
            return 0
        }
        return calendar.dateComponents([.day], from: lhsDate, to: rhsDate).day ?? 0
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
