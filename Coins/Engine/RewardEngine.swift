import Foundation

enum RewardEngine {
    static func complete(
        activityID: String,
        snapshot: inout GameSnapshot,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> CompletionResult {
        guard let activity = snapshot.config.activities.first(where: { $0.id == activityID }) else {
            let denial = "That activity no longer exists."
            return CompletionResult(events: [], deniedReason: denial, speechText: denial)
        }

        let stats = snapshot.state.stats(for: activityID, at: now, calendar: calendar)
        if activity.dailyMaximum > 0 && stats.completionsToday >= activity.dailyMaximum {
            let denial = "Daily maximum reached for \(activity.title)."
            return CompletionResult(events: [], deniedReason: denial, speechText: denial)
        }

        if let lastCompletedAt = stats.lastCompletedAt {
            let elapsed = now.timeIntervalSince(lastCompletedAt)
            if elapsed < Double(activity.lockoutSeconds) {
                let remaining = Int(ceil(Double(activity.lockoutSeconds) - elapsed))
                let denial = "Lockout active for \(remaining)s."
                return CompletionResult(events: [], deniedReason: denial, speechText: denial)
            }
        }

        let activityEvent = ActivityEvent(
            id: UUID(),
            createdAt: now,
            activityID: activity.id,
            activityTitle: activity.title
        )
        snapshot.state.activityEvents.append(activityEvent)

        var events: [RewardEvent] = []
        events.append(
            recordReward(
                title: activity.title,
                detail: activity.detail,
                coins: activity.baseReward,
                kind: .structured,
                activityEventID: activityEvent.id,
                definitionID: activity.id,
                snapshot: &snapshot,
                now: now
            )
        )

        let completionCount = snapshot.state.stats(for: activityID, at: now, calendar: calendar).completionsToday
        if let bonusCoins = activity.repetitionBonusPreset.bonusCoins(at: completionCount) {
            let plural = bonusCoins == 1 ? "coin" : "coins"

            events.append(
                recordReward(
                    title: "\(activity.title) Repetition Bonus",
                    detail: "\(activity.repetitionBonusPreset.detail(for: completionCount)) Bonus: \(bonusCoins) \(plural).",
                    coins: bonusCoins,
                    kind: .combo,
                    activityEventID: activityEvent.id,
                    definitionID: "\(activity.id)-\(activity.repetitionBonusPreset.rawValue)-\(completionCount)",
                    snapshot: &snapshot,
                    now: now
                )
            )
        }

        events.append(
            contentsOf: updateConfiguredStreaks(
                snapshot: &snapshot,
                activityEvent: activityEvent,
                now: now,
                calendar: calendar
            )
        )

        return CompletionResult(
            events: events,
            deniedReason: nil,
            speechText: events.map(\.title).joined(separator: ". ")
        )
    }

    static func cashOut(snapshot: inout GameSnapshot, now: Date = .now) -> RewardEvent? {
        let uncashedCoins = snapshot.state.pendingCashOutCoins
        guard uncashedCoins > 0 else {
            return nil
        }

        let dollars = snapshot.config.economy.dollars(for: uncashedCoins)
        return recordReward(
            title: "Cash Out",
            detail: String(format: "Converted %d new coins into $%.2f earned.", uncashedCoins, dollars),
            coins: 0,
            kind: .cashOut,
            cashOutDollars: dollars,
            snapshot: &snapshot,
            now: now
        )
    }

    static func adjustCoins(snapshot: inout GameSnapshot, delta: Int, reason: String, now: Date = .now) -> RewardEvent? {
        let actualDelta = max(snapshot.state.coinBalance + delta, 0) - snapshot.state.coinBalance
        guard actualDelta != 0 else {
            return nil
        }

        return recordReward(
            title: actualDelta > 0 ? "Manual Bonus" : "Manual Rewind",
            detail: reason,
            coins: actualDelta,
            kind: .adjustment,
            snapshot: &snapshot,
            now: now
        )
    }

    static func remainingLockout(
        for activity: ActivityDefinition,
        snapshot: GameSnapshot,
        now: Date = .now
    ) -> TimeInterval {
        guard let lastCompletedAt = snapshot.state.stats(for: activity.id, at: now).lastCompletedAt else {
            return 0
        }
        return max(Double(activity.lockoutSeconds) - now.timeIntervalSince(lastCompletedAt), 0)
    }

    static func streakLevel(
        for streak: StreakDefinition,
        snapshot: GameSnapshot,
        at date: Date
    ) -> Int {
        guard let progress = snapshot.state.streakProgress.first(where: { $0.streakID == streak.id }),
              progress.lastUpdatedAt <= date else {
            return 0
        }
        return progress.levelDays
    }

    private static func updateConfiguredStreaks(
        snapshot: inout GameSnapshot,
        activityEvent: ActivityEvent,
        now: Date,
        calendar: Calendar
    ) -> [RewardEvent] {
        var events: [RewardEvent] = []

        for streak in snapshot.config.streaks where streak.activityIDs.contains(activityEvent.activityID) {
            let dailyMinimum = max(streak.dailyMinimum, 1)
            let todayCount = snapshot.state.dailyCompletionCount(
                at: now,
                activityIDs: Set(streak.activityIDs),
                calendar: calendar
            )
            guard todayCount == dailyMinimum else {
                continue
            }

            let levels = streak.bonusPreset.levels.sorted { $0.days < $1.days }
            let completedDays = completedStreakDays(
                for: streak,
                snapshot: snapshot,
                through: now,
                lookbackDays: levels.last?.days ?? 1,
                calendar: calendar
            )
            let today = calendar.startOfDay(for: now)
            let existingLevel = snapshot.state.streakLevel(for: streak.id)
            var currentLevel = levels.last(where: { $0.days == existingLevel })

            if let level = currentLevel,
               breakCount(inLast: level.days, endingAt: today, completedDays: completedDays, calendar: calendar) > level.breakAllowance {
                currentLevel = nil
            }

            let currentLevelDays = currentLevel?.days ?? 0
            let consecutiveDays = consecutiveCompletedDays(endingAt: today, completedDays: completedDays, calendar: calendar)
            let nextLevel = levels.last { $0.days > currentLevelDays && consecutiveDays >= $0.days }
            let awardedLevel = nextLevel ?? currentLevel

            guard let awardedLevel else {
                snapshot.state.setStreakLevel(0, for: streak.id, at: now)
                continue
            }

            snapshot.state.setStreakLevel(awardedLevel.days, for: streak.id, at: now)
            let detail = streak.detail.isEmpty
                ? "\(awardedLevel.days) days: +\(awardedLevel.rewardCoins) bonus coins."
                : "\(streak.detail) \(awardedLevel.days) days: +\(awardedLevel.rewardCoins) bonus coins."
            events.append(
                recordReward(
                    title: streak.title,
                    detail: detail,
                    coins: awardedLevel.rewardCoins,
                    kind: .dailyStreak,
                    activityEventID: activityEvent.id,
                    definitionID: streak.id,
                    snapshot: &snapshot,
                    now: now
                )
            )
        }

        return events
    }

    private static func recordReward(
        title: String,
        detail: String,
        coins: Int,
        kind: RewardKind,
        activityEventID: UUID? = nil,
        definitionID: String? = nil,
        cashOutDollars: Double? = nil,
        snapshot: inout GameSnapshot,
        now: Date
    ) -> RewardEvent {
        let recordedCoins = kind == .adjustment ? coins : max(coins, 0)
        let event = RewardEvent(
            id: UUID(),
            createdAt: now,
            title: title,
            detail: detail,
            coins: recordedCoins,
            kind: kind,
            activityEventID: activityEventID,
            definitionID: definitionID,
            cashOutDollars: cashOutDollars
        )
        snapshot.state.rewardEvents.append(event)
        return event
    }

    private static func completedStreakDays(
        for streak: StreakDefinition,
        snapshot: GameSnapshot,
        through date: Date,
        lookbackDays: Int,
        calendar: Calendar
    ) -> Set<Date> {
        let dailyMinimum = max(streak.dailyMinimum, 1)
        let today = calendar.startOfDay(for: date)
        let oldestDay = calendar.date(
            byAdding: .day,
            value: -max(lookbackDays - 1, 0),
            to: today
        ) ?? today
        var counts: [Date: Int] = [:]
        for event in snapshot.state.activityEvents where streak.activityIDs.contains(event.activityID) && event.createdAt <= date {
            let eventDay = calendar.startOfDay(for: event.createdAt)
            guard eventDay >= oldestDay else {
                continue
            }
            counts[eventDay, default: 0] += 1
        }
        return Set(counts.compactMap { day, count in
            count >= dailyMinimum ? day : nil
        })
    }

    private static func consecutiveCompletedDays(
        endingAt date: Date,
        completedDays: Set<Date>,
        calendar: Calendar
    ) -> Int {
        var count = 0
        var cursor = date
        while completedDays.contains(cursor) {
            count += 1
            guard let priorDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = priorDay
        }
        return count
    }

    private static func breakCount(
        inLast days: Int,
        endingAt date: Date,
        completedDays: Set<Date>,
        calendar: Calendar
    ) -> Int {
        guard days > 0 else {
            return 0
        }

        return (0..<days).reduce(0) { count, offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else {
                return count
            }
            return completedDays.contains(day) ? count : count + 1
        }
    }
}
