import Foundation

enum ThemeID: String, Codable, CaseIterable, Identifiable {
    case coins

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "coins", "coinGarden":
            self = .coins
        default:
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown theme: \(value)")
            )
        }
    }
}

struct ActivityDefinition: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var detail: String
    var baseReward: Int
    var lockoutSeconds: Int
    var symbol: String
}

struct DailyCompletionBonusDefinition: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var detail: String
    var activityIDs: [String]
    var threshold: Int
    var rewardCoins: Int
}

enum StreakFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case every2Days
    case every3Days
    case every4Days
    case every5Days
    case weekly
    case every2Weeks
    case every3Weeks
    case every4Weeks
    case monthly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily:
            return "Daily"
        case .every2Days:
            return "Every 2 Days"
        case .every3Days:
            return "Every 3 Days"
        case .every4Days:
            return "Every 4 Days"
        case .every5Days:
            return "Every 5 Days"
        case .weekly:
            return "Weekly"
        case .every2Weeks:
            return "Every 2 Weeks"
        case .every3Weeks:
            return "Every 3 Weeks"
        case .every4Weeks:
            return "Every 4 Weeks"
        case .monthly:
            return "Monthly"
        }
    }

    var interval: Int {
        switch self {
        case .daily, .weekly, .monthly:
            return 1
        case .every2Days, .every2Weeks:
            return 2
        case .every3Days, .every3Weeks:
            return 3
        case .every4Days, .every4Weeks:
            return 4
        case .every5Days:
            return 5
        }
    }

    var unitName: String {
        switch self {
        case .daily, .every2Days, .every3Days, .every4Days, .every5Days:
            return "day"
        case .weekly, .every2Weeks, .every3Weeks, .every4Weeks:
            return "week"
        case .monthly:
            return "month"
        }
    }

    var progressUnitName: String {
        interval == 1 ? unitName : "\(interval)-\(unitName) period"
    }
}

struct StreakDefinition: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var detail: String
    var activityIDs: [String]
    var frequency: StreakFrequency
    var minimumLength: Int
    var rewardCoins: Int
    var extraRewardCoins: Int
    var symbol: String

    init(
        id: String,
        title: String,
        detail: String,
        activityIDs: [String],
        frequency: StreakFrequency,
        minimumLength: Int,
        rewardCoins: Int,
        extraRewardCoins: Int,
        symbol: String = "flame.fill"
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.activityIDs = activityIDs
        self.frequency = frequency
        self.minimumLength = minimumLength
        self.rewardCoins = rewardCoins
        self.extraRewardCoins = extraRewardCoins
        self.symbol = symbol
    }
}

enum AchievementMetric: String, Codable, CaseIterable {
    case totalCompletions
    case lifetimeCoins
    case dailyStreak
    case activityCompletions
}

struct AchievementDefinition: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var detail: String
    var metric: AchievementMetric
    var threshold: Int
    var rewardCoins: Int
    var activityID: String?
}

struct RandomDropConfig: Codable, Hashable {
    var isEnabled: Bool
    var minDailyStreak: Int
    var minDailyCompletions: Int
    var chance: Double
    var minCoins: Int
    var maxCoins: Int
}

struct EconomyConfig: Codable, Hashable {
    var coinsPerDollar: Double
}

struct GameConfig: Codable, Hashable {
    var theme: ThemeID
    var speechEnabled: Bool
    var masterPassword: String
    var activities: [ActivityDefinition]
    var dailyCompletionBonuses: [DailyCompletionBonusDefinition]
    var streaks: [StreakDefinition]
    var achievements: [AchievementDefinition]
    var randomDrops: RandomDropConfig
    var economy: EconomyConfig
}

enum RewardKind: String, Codable {
    case structured
    case combo
    case dailyStreak
    case treasureChest
    case achievement
    case adjustment
    case cashOut
}

struct ActivityEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var createdAt: Date
    var activityID: String
    var activityTitle: String
}

struct DeniedActivityEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var createdAt: Date
    var activityID: String
    var activityTitle: String
    var detail: String
}

struct RewardEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var createdAt: Date
    var title: String
    var detail: String
    var coins: Int
    var kind: RewardKind
    var activityEventID: UUID?
    var definitionID: String?
    var cashOutCoins: Int?
    var cashOutDollars: Double?
}

struct RewardHistoryEntry: Identifiable, Hashable {
    var event: RewardEvent
    var balanceAfter: Int

    var id: UUID { event.id }
}

struct ActivityStats: Hashable {
    var totalCompletions: Int
    var completionsToday: Int
    var lastCompletedAt: Date?
}

struct GameState: Codable, Hashable {
    var activityEvents: [ActivityEvent]
    var rewardEvents: [RewardEvent]
    var deniedActivityEvents: [DeniedActivityEvent]

    init(
        activityEvents: [ActivityEvent] = [],
        rewardEvents: [RewardEvent] = [],
        deniedActivityEvents: [DeniedActivityEvent] = []
    ) {
        self.activityEvents = activityEvents
        self.rewardEvents = rewardEvents
        self.deniedActivityEvents = deniedActivityEvents
    }
}

struct GameSnapshot: Codable, Hashable {
    var config: GameConfig
    var state: GameState
}

struct CompletionResult: Hashable {
    var events: [RewardEvent]
    var deniedReason: String?
    var speechText: String

    var totalCoinsAwarded: Int {
        events.reduce(0) { $0 + $1.coins }
    }

    var isDenied: Bool {
        deniedReason != nil
    }
}

extension GameSnapshot {
    static let seed = GameSnapshot(
        config: GameConfig(
            theme: .coins,
            speechEnabled: false,
            masterPassword: "1234",
            activities: [
                ActivityDefinition(
                    id: "warmup",
                    title: "Warm-Up",
                    detail: "Two focused minutes to get started.",
                    baseReward: 1,
                    lockoutSeconds: 300,
                    symbol: "leaf.fill"
                ),
                ActivityDefinition(
                    id: "song-practice",
                    title: "Song Practice",
                    detail: "Run one assigned song from start to finish.",
                    baseReward: 2,
                    lockoutSeconds: 600,
                    symbol: "music.note"
                ),
                ActivityDefinition(
                    id: "sight-reading",
                    title: "Sight Reading",
                    detail: "Try something new without stopping.",
                    baseReward: 2,
                    lockoutSeconds: 600,
                    symbol: "eye.fill"
                )
            ],
            dailyCompletionBonuses: [
                DailyCompletionBonusDefinition(
                    id: "combo-2",
                    title: "Quick Double",
                    detail: "You hit 2 total completions today.",
                    activityIDs: ["warmup", "song-practice", "sight-reading"],
                    threshold: 2,
                    rewardCoins: 1
                ),
                DailyCompletionBonusDefinition(
                    id: "combo-4",
                    title: "Practice Wave",
                    detail: "You hit 4 total completions today.",
                    activityIDs: ["warmup", "song-practice", "sight-reading"],
                    threshold: 4,
                    rewardCoins: 3
                )
            ],
            streaks: [
                StreakDefinition(
                    id: "streak-3",
                    title: "Three-Day Spark",
                    detail: "Complete any practice activity three days in a row.",
                    activityIDs: ["warmup", "song-practice", "sight-reading"],
                    frequency: .daily,
                    minimumLength: 3,
                    rewardCoins: 4,
                    extraRewardCoins: 0,
                    symbol: "sparkles"
                ),
                StreakDefinition(
                    id: "streak-7",
                    title: "Weeklong Shine",
                    detail: "Complete any practice activity for a full week.",
                    activityIDs: ["warmup", "song-practice", "sight-reading"],
                    frequency: .daily,
                    minimumLength: 7,
                    rewardCoins: 10,
                    extraRewardCoins: 0,
                    symbol: "sun.max.fill"
                )
            ],
            achievements: [
                AchievementDefinition(
                    id: "first-10",
                    title: "Treasure Hunter",
                    detail: "Complete ten activities total.",
                    metric: .totalCompletions,
                    threshold: 10,
                    rewardCoins: 5,
                    activityID: nil
                ),
                AchievementDefinition(
                    id: "coins-25",
                    title: "Piggy Bank Builder",
                    detail: "Reach 25 lifetime coins.",
                    metric: .lifetimeCoins,
                    threshold: 25,
                    rewardCoins: 5,
                    activityID: nil
                ),
                AchievementDefinition(
                    id: "song-12",
                    title: "Songsmith",
                    detail: "Practice the same song activity twelve times.",
                    metric: .activityCompletions,
                    threshold: 12,
                    rewardCoins: 8,
                    activityID: "song-practice"
                )
            ],
            randomDrops: RandomDropConfig(
                isEnabled: true,
                minDailyStreak: 2,
                minDailyCompletions: 2,
                chance: 0.35,
                minCoins: 3,
                maxCoins: 7
            ),
            economy: EconomyConfig(coinsPerDollar: 20)
        ),
        state: GameState()
    )
}

extension GameState {
    var coinBalance: Int {
        rewardEvents.reduce(0) { $0 + $1.coins }
    }

    var lifetimeCoins: Int {
        rewardEvents.reduce(0) { total, event in
            total + max(event.coins, 0)
        }
    }

    var suspiciousTapCount: Int {
        deniedActivityEvents.count
    }

    var cashedOutCoinsWatermark: Int {
        var balance = 0
        var watermark = 0

        for event in rewardEvents {
            balance += event.coins
            if event.kind == .cashOut {
                watermark = balance
            } else if event.coins < 0 {
                watermark = min(watermark, balance)
            }
        }

        return watermark
    }

    var cashedOutDollars: Double {
        rewardEvents.reduce(0) { $0 + ($1.cashOutDollars ?? 0) }
    }

    var pendingCashOutCoins: Int {
        max(coinBalance - cashedOutCoinsWatermark, 0)
    }

    var dailyCompletionCount: Int {
        dailyCompletionCount(at: .now)
    }

    var dailyStreak: Int {
        activeDailyStreak(at: .now)
    }

    var unlockedAchievementIDs: Set<String> {
        Set(
            rewardEvents.compactMap { event in
                event.kind == .achievement ? event.definitionID : nil
            }
        )
    }

    var rewardHistory: [RewardHistoryEntry] {
        var balance = 0
        return rewardEvents.map { event in
            balance += event.coins
            return RewardHistoryEntry(event: event, balanceAfter: balance)
        }
    }

    func stats(for activityID: String, at date: Date = .now, calendar: Calendar = .current) -> ActivityStats {
        let matchingEvents = activityEvents.filter { $0.activityID == activityID }
        return ActivityStats(
            totalCompletions: matchingEvents.count,
            completionsToday: matchingEvents.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }.count,
            lastCompletedAt: matchingEvents.map(\.createdAt).max()
        )
    }

    func dailyCompletionCount(
        at date: Date,
        activityIDs: Set<String>? = nil,
        calendar: Calendar = .current
    ) -> Int {
        activityEvents.filter { event in
            calendar.isDate(event.createdAt, inSameDayAs: date)
                && (activityIDs?.contains(event.activityID) ?? true)
        }.count
    }

    func activeDailyStreak(at date: Date, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: date)
        let completionDays = Set(activityEvents.map { calendar.startOfDay(for: $0.createdAt) })
            .filter { $0 <= today }
            .sorted()

        guard let latestDay = completionDays.last else {
            return 0
        }

        let latestGap = calendar.dateComponents([.day], from: latestDay, to: today).day ?? 0
        guard latestGap <= 1 else {
            return 0
        }

        var streak = 1
        var currentDay = latestDay
        for priorDay in completionDays.dropLast().reversed() {
            let gap = calendar.dateComponents([.day], from: priorDay, to: currentDay).day ?? 0
            guard gap == 1 else {
                break
            }
            streak += 1
            currentDay = priorDay
        }
        return streak
    }
}

extension AchievementMetric {
    func value(
        for achievement: AchievementDefinition,
        in state: GameState,
        at date: Date,
        calendar: Calendar
    ) -> Int {
        switch self {
        case .totalCompletions:
            return state.activityEvents.count
        case .lifetimeCoins:
            return state.lifetimeCoins
        case .dailyStreak:
            return state.activeDailyStreak(at: date, calendar: calendar)
        case .activityCompletions:
            guard let activityID = achievement.activityID else {
                return 0
            }
            return state.stats(for: activityID, at: date, calendar: calendar).totalCompletions
        }
    }
}

extension GameConfig {
    private enum CodingKeys: String, CodingKey {
        case theme
        case speechEnabled
        case masterPassword
        case activities
        case dailyCompletionBonuses
        case comboMilestones
        case streaks
        case dailyStreakMilestones
        case achievements
        case randomDrops
        case treasureChest
        case economy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let activities = try container.decodeIfPresent([ActivityDefinition].self, forKey: .activities) ?? []
        let dailyCompletionBonuses = try container.decodeIfPresent(
            [DailyCompletionBonusDefinition].self,
            forKey: .dailyCompletionBonuses
        ) ?? (try container.decodeIfPresent([LegacyComboMilestone].self, forKey: .comboMilestones) ?? []).map { milestone in
            DailyCompletionBonusDefinition(
                id: milestone.id,
                title: milestone.title,
                detail: "You hit \(milestone.count) total completions today.",
                activityIDs: activities.map(\.id),
                threshold: milestone.count,
                rewardCoins: milestone.bonusCoins
            )
        }
        let streaks = try container.decodeIfPresent([StreakDefinition].self, forKey: .streaks)
            ?? (try container.decodeIfPresent([LegacyDailyStreakMilestone].self, forKey: .dailyStreakMilestones) ?? []).map { milestone in
                StreakDefinition(
                    id: milestone.id,
                    title: milestone.title,
                    detail: "Complete a qualifying activity \(milestone.days) days in a row.",
                    activityIDs: activities.map(\.id),
                    frequency: .daily,
                    minimumLength: milestone.days,
                    rewardCoins: milestone.bonusCoins,
                    extraRewardCoins: 0,
                    symbol: "flame.fill"
                )
            }

        self.init(
            theme: try container.decodeIfPresent(ThemeID.self, forKey: .theme) ?? .coins,
            speechEnabled: try container.decodeIfPresent(Bool.self, forKey: .speechEnabled) ?? false,
            masterPassword: try container.decodeIfPresent(String.self, forKey: .masterPassword) ?? "1234",
            activities: activities,
            dailyCompletionBonuses: dailyCompletionBonuses,
            streaks: streaks,
            achievements: try container.decodeIfPresent([AchievementDefinition].self, forKey: .achievements) ?? [],
            randomDrops: try container.decodeIfPresent(RandomDropConfig.self, forKey: .randomDrops)
                ?? container.decodeIfPresent(RandomDropConfig.self, forKey: .treasureChest)
                ?? RandomDropConfig(
                    isEnabled: true,
                    minDailyStreak: 2,
                    minDailyCompletions: 2,
                    chance: 0.35,
                    minCoins: 3,
                    maxCoins: 7
                ),
            economy: try container.decodeIfPresent(EconomyConfig.self, forKey: .economy)
                ?? EconomyConfig(coinsPerDollar: 20)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(theme, forKey: .theme)
        try container.encode(speechEnabled, forKey: .speechEnabled)
        try container.encode(masterPassword, forKey: .masterPassword)
        try container.encode(activities, forKey: .activities)
        try container.encode(dailyCompletionBonuses, forKey: .dailyCompletionBonuses)
        try container.encode(streaks, forKey: .streaks)
        try container.encode(achievements, forKey: .achievements)
        try container.encode(randomDrops, forKey: .randomDrops)
        try container.encode(economy, forKey: .economy)
    }
}

extension StreakDefinition {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case detail
        case activityIDs
        case frequency
        case minimumLength
        case rewardCoins
        case extraRewardCoins
        case symbol
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            detail: try container.decode(String.self, forKey: .detail),
            activityIDs: try container.decode([String].self, forKey: .activityIDs),
            frequency: try container.decode(StreakFrequency.self, forKey: .frequency),
            minimumLength: try container.decode(Int.self, forKey: .minimumLength),
            rewardCoins: try container.decode(Int.self, forKey: .rewardCoins),
            extraRewardCoins: try container.decode(Int.self, forKey: .extraRewardCoins),
            symbol: try container.decodeIfPresent(String.self, forKey: .symbol) ?? "flame.fill"
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(detail, forKey: .detail)
        try container.encode(activityIDs, forKey: .activityIDs)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(minimumLength, forKey: .minimumLength)
        try container.encode(rewardCoins, forKey: .rewardCoins)
        try container.encode(extraRewardCoins, forKey: .extraRewardCoins)
        try container.encode(symbol, forKey: .symbol)
    }
}

extension GameState {
    private enum CodingKeys: String, CodingKey {
        case activityEvents
        case rewardEvents
        case deniedActivityEvents
        case suspiciousTapCount
        case unlockedAchievementIDs
        case ledger
        case cashedOutDollars
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let activityEvents = try container.decodeIfPresent([ActivityEvent].self, forKey: .activityEvents) ?? []
        var rewardEvents = try container.decodeIfPresent([RewardEvent].self, forKey: .rewardEvents) ?? []
        var deniedActivityEvents = try container.decodeIfPresent([DeniedActivityEvent].self, forKey: .deniedActivityEvents) ?? []

        if rewardEvents.isEmpty {
            let ledger = try container.decodeIfPresent([LegacyLedgerEntry].self, forKey: .ledger) ?? []
            rewardEvents = Self.migrate(ledger: ledger)
        }

        if deniedActivityEvents.isEmpty {
            let suspiciousTapCount = try container.decodeIfPresent(Int.self, forKey: .suspiciousTapCount) ?? 0
            deniedActivityEvents = (0..<suspiciousTapCount).map { _ in
                DeniedActivityEvent(
                    id: UUID(),
                    createdAt: Date(timeIntervalSince1970: 0),
                    activityID: "unknown",
                    activityTitle: "Unknown Activity",
                    detail: "Migrated suspicious tap."
                )
            }
        }

        let legacyCashedOutDollars = try container.decodeIfPresent(Double.self, forKey: .cashedOutDollars) ?? 0
        if legacyCashedOutDollars > 0,
           rewardEvents.allSatisfy({ $0.cashOutDollars == nil }),
           let lastCashOutIndex = rewardEvents.lastIndex(where: { $0.kind == .cashOut }) {
            rewardEvents[lastCashOutIndex].cashOutDollars = legacyCashedOutDollars
        }

        let migratedAchievementIDs = try container.decodeIfPresent(Set<String>.self, forKey: .unlockedAchievementIDs) ?? []
        let recordedAchievementIDs = Set(
            rewardEvents.compactMap { event in
                event.kind == .achievement ? event.definitionID : nil
            }
        )
        rewardEvents.insert(
            contentsOf: migratedAchievementIDs.subtracting(recordedAchievementIDs).map { achievementID in
                RewardEvent(
                    id: UUID(),
                    createdAt: Date(timeIntervalSince1970: 0),
                    title: "Migrated Achievement",
                    detail: "Unlocked before reward-event history was introduced.",
                    coins: 0,
                    kind: .achievement,
                    activityEventID: nil,
                    definitionID: achievementID,
                    cashOutCoins: nil,
                    cashOutDollars: nil
                )
            },
            at: 0
        )

        self.init(
            activityEvents: activityEvents,
            rewardEvents: rewardEvents,
            deniedActivityEvents: deniedActivityEvents
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activityEvents, forKey: .activityEvents)
        try container.encode(rewardEvents, forKey: .rewardEvents)
        try container.encode(deniedActivityEvents, forKey: .deniedActivityEvents)
    }

    private static func migrate(ledger: [LegacyLedgerEntry]) -> [RewardEvent] {
        let chronologicalEntries = ledger.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.createdAt == rhs.element.createdAt {
                    return lhs.offset > rhs.offset
                }
                return lhs.element.createdAt < rhs.element.createdAt
            }
            .map(\.element)

        var balance = 0
        var cashOutWatermark = 0
        return chronologicalEntries.map { entry in
            let coins = entry.kind == .cashOut ? 0 : entry.balanceAfter - balance
            balance = entry.balanceAfter

            let cashOutCoins: Int?
            if entry.kind == .cashOut {
                cashOutCoins = max(balance - cashOutWatermark, 0)
                cashOutWatermark = balance
            } else {
                cashOutCoins = nil
                if coins < 0 {
                    cashOutWatermark = min(cashOutWatermark, balance)
                }
            }

            return RewardEvent(
                id: entry.id,
                createdAt: entry.createdAt,
                title: entry.title,
                detail: entry.detail,
                coins: coins,
                kind: entry.kind,
                activityEventID: nil,
                definitionID: nil,
                cashOutCoins: cashOutCoins,
                cashOutDollars: nil
            )
        }
    }
}

private struct LegacyComboMilestone: Codable {
    var id: String
    var count: Int
    var bonusCoins: Int
    var title: String
}

private struct LegacyDailyStreakMilestone: Codable {
    var id: String
    var days: Int
    var bonusCoins: Int
    var title: String
}

private struct LegacyLedgerEntry: Codable {
    var id: UUID
    var createdAt: Date
    var title: String
    var detail: String
    var coins: Int
    var balanceAfter: Int
    var kind: RewardKind
}
