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
            let denial = "That activity no longer exists."
            return CompletionResult(events: [], deniedReason: denial, speechText: denial)
        }

        if let lastCompletedAt = snapshot.state.stats(for: activityID, at: now, calendar: calendar).lastCompletedAt {
            let elapsed = now.timeIntervalSince(lastCompletedAt)
            if elapsed < Double(activity.lockoutSeconds) {
                let remaining = Int(ceil(Double(activity.lockoutSeconds) - elapsed))
                let denial = "Lockout active for \(remaining)s."
                snapshot.state.deniedActivityEvents.append(
                    DeniedActivityEvent(
                        id: UUID(),
                        createdAt: now,
                        activityID: activity.id,
                        activityTitle: activity.title,
                        detail: denial
                    )
                )
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

        for bonus in snapshot.config.dailyCompletionBonuses where bonus.activityIDs.contains(activityID) {
            let completionCount = snapshot.state.dailyCompletionCount(
                at: now,
                activityIDs: Set(bonus.activityIDs),
                calendar: calendar
            )
            guard completionCount == max(bonus.threshold, 1) else {
                continue
            }

            events.append(
                recordReward(
                    title: bonus.title,
                    detail: bonus.detail,
                    coins: bonus.rewardCoins,
                    kind: .combo,
                    activityEventID: activityEvent.id,
                    definitionID: bonus.id,
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

        if let chestCoins = treasureChestCoins(snapshot: snapshot, now: now, roll: roll, chestCoins: chestCoins, calendar: calendar) {
            events.append(
                recordReward(
                    title: "Treasure Chest",
                    detail: "A surprise reward dropped.",
                    coins: chestCoins,
                    kind: .treasureChest,
                    activityEventID: activityEvent.id,
                    snapshot: &snapshot,
                    now: now
                )
            )
        }

        events.append(
            contentsOf: unlockAchievements(
                snapshot: &snapshot,
                activityEventID: activityEvent.id,
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

        let coinsPerDollar = max(snapshot.config.economy.coinsPerDollar, 1)
        let dollars = Double(uncashedCoins) / coinsPerDollar
        return recordReward(
            title: "Cash Out",
            detail: String(format: "Converted %d new coins into $%.2f earned.", uncashedCoins, dollars),
            coins: 0,
            kind: .cashOut,
            cashOutCoins: uncashedCoins,
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

    static func streakLength(
        for streak: StreakDefinition,
        snapshot: GameSnapshot,
        at date: Date,
        calendar: Calendar = .current
    ) -> Int {
        let periodKeys = Set(
            snapshot.state.activityEvents
                .filter { streak.activityIDs.contains($0.activityID) && $0.createdAt <= date }
                .map { periodKey(for: $0.createdAt, frequency: streak.frequency, calendar: calendar) }
        ).sorted()

        guard let latestPeriodKey = periodKeys.last,
              latestPeriodKey == periodKey(for: date, frequency: streak.frequency, calendar: calendar) else {
            return 0
        }

        var length = 1
        var currentPeriodKey = latestPeriodKey
        for priorPeriodKey in periodKeys.dropLast().reversed() {
            guard periodDistance(
                from: priorPeriodKey,
                to: currentPeriodKey,
                frequency: streak.frequency,
                calendar: calendar
            ) == 1 else {
                break
            }
            length += 1
            currentPeriodKey = priorPeriodKey
        }
        return length
    }

    private static func updateConfiguredStreaks(
        snapshot: inout GameSnapshot,
        activityEvent: ActivityEvent,
        now: Date,
        calendar: Calendar
    ) -> [RewardEvent] {
        var events: [RewardEvent] = []

        for streak in snapshot.config.streaks where streak.activityIDs.contains(activityEvent.activityID) {
            let completedPeriodKey = periodKey(for: now, frequency: streak.frequency, calendar: calendar)
            let alreadyCompletedPeriod = snapshot.state.activityEvents.contains { event in
                event.id != activityEvent.id
                    && streak.activityIDs.contains(event.activityID)
                    && periodKey(for: event.createdAt, frequency: streak.frequency, calendar: calendar) == completedPeriodKey
            }
            guard !alreadyCompletedPeriod else {
                continue
            }

            let length = streakLength(for: streak, snapshot: snapshot, at: now, calendar: calendar)
            let minimumLength = max(streak.minimumLength, 1)
            guard length >= minimumLength else {
                continue
            }

            let extraPeriods = max(length - minimumLength, 0)
            let coins = max(streak.rewardCoins, 0) + extraPeriods * max(streak.extraRewardCoins, 0)
            let unit = streak.frequency.progressUnitName
            let pluralUnit = length == 1 ? unit : "\(unit)s"
            let detail = streak.detail.isEmpty
                ? "\(length) \(pluralUnit) in a row."
                : "\(streak.detail) \(length) \(pluralUnit) in a row."
            events.append(
                recordReward(
                    title: streak.title,
                    detail: detail,
                    coins: coins,
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

    private static func treasureChestCoins(
        snapshot: GameSnapshot,
        now: Date,
        roll: Double?,
        chestCoins: Int?,
        calendar: Calendar
    ) -> Int? {
        let config = snapshot.config.randomDrops
        guard config.isEnabled else { return nil }
        guard snapshot.state.activeDailyStreak(at: now, calendar: calendar) >= config.minDailyStreak else { return nil }
        guard snapshot.state.dailyCompletionCount(at: now, calendar: calendar) >= config.minDailyCompletions else { return nil }

        let draw = roll ?? Double.random(in: 0...1)
        guard draw <= min(max(config.chance, 0), 1) else { return nil }

        let minimumCoins = max(config.minCoins, 0)
        let maximumCoins = max(config.maxCoins, minimumCoins)
        return max(chestCoins ?? Int.random(in: minimumCoins...maximumCoins), 0)
    }

    private static func unlockAchievements(
        snapshot: inout GameSnapshot,
        activityEventID: UUID,
        now: Date,
        calendar: Calendar
    ) -> [RewardEvent] {
        var events: [RewardEvent] = []

        for achievement in snapshot.config.achievements where !snapshot.state.unlockedAchievementIDs.contains(achievement.id) {
            let metricValue = achievement.metric.value(
                for: achievement,
                in: snapshot.state,
                at: now,
                calendar: calendar
            )
            guard metricValue >= achievement.threshold else {
                continue
            }

            events.append(
                recordReward(
                    title: achievement.title,
                    detail: achievement.detail,
                    coins: achievement.rewardCoins,
                    kind: .achievement,
                    activityEventID: activityEventID,
                    definitionID: achievement.id,
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
        cashOutCoins: Int? = nil,
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
            cashOutCoins: cashOutCoins,
            cashOutDollars: cashOutDollars
        )
        snapshot.state.rewardEvents.append(event)
        return event
    }

    private static func periodKey(for date: Date, frequency: StreakFrequency, calendar: Calendar) -> String {
        dayKey(for: periodStart(for: date, frequency: frequency, calendar: calendar), calendar: calendar)
    }

    private static func periodStart(for date: Date, frequency: StreakFrequency, calendar: Calendar) -> Date {
        switch frequency {
        case .daily, .every2Days, .every3Days, .every4Days, .every5Days:
            return bucketedStart(
                for: calendar.startOfDay(for: date),
                component: .day,
                interval: frequency.interval,
                calendar: calendar
            )
        case .weekly, .every2Weeks, .every3Weeks, .every4Weeks:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
            return bucketedStart(
                for: weekStart,
                component: .weekOfYear,
                interval: frequency.interval,
                calendar: calendar
            )
        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        }
    }

    private static func periodDistance(
        from lhs: String,
        to rhs: String,
        frequency: StreakFrequency,
        calendar: Calendar
    ) -> Int {
        guard let lhsDate = date(fromDayKey: lhs, calendar: calendar),
              let rhsDate = date(fromDayKey: rhs, calendar: calendar) else {
            return 0
        }

        let component: Calendar.Component
        switch frequency {
        case .daily, .every2Days, .every3Days, .every4Days, .every5Days:
            component = .day
        case .weekly, .every2Weeks, .every3Weeks, .every4Weeks:
            component = .weekOfYear
        case .monthly:
            component = .month
        }

        let distance = calendar.dateComponents([component], from: lhsDate, to: rhsDate).value(for: component) ?? 0
        return distance / max(frequency.interval, 1)
    }

    private static func bucketedStart(
        for date: Date,
        component: Calendar.Component,
        interval: Int,
        calendar: Calendar
    ) -> Date {
        guard interval > 1,
              let referenceDate = calendar.date(from: DateComponents(year: 2001, month: 1, day: 1)) else {
            return date
        }

        let referenceStart: Date
        if component == .weekOfYear {
            referenceStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? calendar.startOfDay(for: referenceDate)
        } else {
            referenceStart = calendar.startOfDay(for: referenceDate)
        }

        let distance = calendar.dateComponents([component], from: referenceStart, to: date).value(for: component) ?? 0
        let bucketDistance = distance - distance.modulo(interval)
        return calendar.date(byAdding: component, value: bucketDistance, to: referenceStart) ?? date
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static func date(fromDayKey dayKey: String, calendar: Calendar) -> Date? {
        let values = dayKey.split(separator: "-").compactMap { Int($0) }
        guard values.count == 3 else {
            return nil
        }
        return calendar.date(from: DateComponents(year: values[0], month: values[1], day: values[2]))
    }
}

private extension Int {
    func modulo(_ divisor: Int) -> Int {
        let remainder = self % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
