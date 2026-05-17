import Foundation

enum ThemeID: String, Codable, CaseIterable, Identifiable {
    case coinGarden

    var id: String { rawValue }
}

struct Activity: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var detail: String
    var baseReward: Int
    var lockoutSeconds: Int
    var symbol: String
}

struct ComboMilestone: Identifiable, Codable, Hashable {
    var id: String
    var count: Int
    var bonusCoins: Int
    var title: String
}

struct DailyStreakMilestone: Identifiable, Codable, Hashable {
    var id: String
    var days: Int
    var bonusCoins: Int
    var title: String
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

struct TreasureChestConfig: Codable, Hashable {
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
    var activities: [Activity]
    var comboMilestones: [ComboMilestone]
    var streaks: [StreakDefinition]
    var achievements: [AchievementDefinition]
    var treasureChest: TreasureChestConfig
    var economy: EconomyConfig

    init(
        theme: ThemeID,
        speechEnabled: Bool,
        masterPassword: String,
        activities: [Activity],
        comboMilestones: [ComboMilestone],
        streaks: [StreakDefinition],
        achievements: [AchievementDefinition],
        treasureChest: TreasureChestConfig,
        economy: EconomyConfig
    ) {
        self.theme = theme
        self.speechEnabled = speechEnabled
        self.masterPassword = masterPassword
        self.activities = activities
        self.comboMilestones = comboMilestones
        self.streaks = streaks
        self.achievements = achievements
        self.treasureChest = treasureChest
        self.economy = economy
    }
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

struct RewardEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var detail: String
    var coins: Int
    var kind: RewardKind
}

struct LedgerEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var createdAt: Date
    var title: String
    var detail: String
    var coins: Int
    var balanceAfter: Int
    var kind: RewardKind
}

struct ActivityProgress: Codable, Hashable {
    var totalCompletions: Int = 0
    var completionsToday: Int = 0
    var lastCompletedAt: Date?
    var lastCompletedDayKey: String?
}

struct StreakProgress: Codable, Hashable {
    var currentLength: Int = 0
    var lastCompletedPeriodKey: String?
}

struct GameState: Codable, Hashable {
    var coinBalance: Int = 0
    var lifetimeCoins: Int = 0
    var dailyStreak: Int = 0
    var dailyCompletionCount: Int = 0
    var currentDayKey: String?
    var lastActiveDayKey: String?
    var suspiciousTapCount: Int = 0
    var cashedOutCoinsWatermark: Int = 0
    var cashedOutDollars: Double = 0
    var activityProgress: [String: ActivityProgress] = [:]
    var streakProgress: [String: StreakProgress] = [:]
    var unlockedAchievementIDs: Set<String> = []
    var ledger: [LedgerEntry] = []

    init(
        coinBalance: Int = 0,
        lifetimeCoins: Int = 0,
        dailyStreak: Int = 0,
        dailyCompletionCount: Int = 0,
        currentDayKey: String? = nil,
        lastActiveDayKey: String? = nil,
        suspiciousTapCount: Int = 0,
        cashedOutCoinsWatermark: Int = 0,
        cashedOutDollars: Double = 0,
        activityProgress: [String: ActivityProgress] = [:],
        streakProgress: [String: StreakProgress] = [:],
        unlockedAchievementIDs: Set<String> = [],
        ledger: [LedgerEntry] = []
    ) {
        self.coinBalance = coinBalance
        self.lifetimeCoins = lifetimeCoins
        self.dailyStreak = dailyStreak
        self.dailyCompletionCount = dailyCompletionCount
        self.currentDayKey = currentDayKey
        self.lastActiveDayKey = lastActiveDayKey
        self.suspiciousTapCount = suspiciousTapCount
        self.cashedOutCoinsWatermark = cashedOutCoinsWatermark
        self.cashedOutDollars = cashedOutDollars
        self.activityProgress = activityProgress
        self.streakProgress = streakProgress
        self.unlockedAchievementIDs = unlockedAchievementIDs
        self.ledger = ledger
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
            theme: .coinGarden,
            speechEnabled: false,
            masterPassword: "1234",
            activities: [
                Activity(
                    id: "warmup",
                    title: "Warm-Up",
                    detail: "Two focused minutes to get started.",
                    baseReward: 1,
                    lockoutSeconds: 300,
                    symbol: "leaf.fill"
                ),
                Activity(
                    id: "song-practice",
                    title: "Song Practice",
                    detail: "Run one assigned song from start to finish.",
                    baseReward: 2,
                    lockoutSeconds: 600,
                    symbol: "music.note"
                ),
                Activity(
                    id: "sight-reading",
                    title: "Sight Reading",
                    detail: "Try something new without stopping.",
                    baseReward: 2,
                    lockoutSeconds: 600,
                    symbol: "eye.fill"
                )
            ],
            comboMilestones: [
                ComboMilestone(id: "combo-2", count: 2, bonusCoins: 1, title: "Quick Double"),
                ComboMilestone(id: "combo-4", count: 4, bonusCoins: 3, title: "Practice Wave")
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
            treasureChest: TreasureChestConfig(
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

extension GameConfig {
    private enum CodingKeys: String, CodingKey {
        case theme
        case speechEnabled
        case masterPassword
        case activities
        case comboMilestones
        case streaks
        case dailyStreakMilestones
        case achievements
        case treasureChest
        case economy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let activities = try container.decodeIfPresent([Activity].self, forKey: .activities) ?? []
        let streaks = try container.decodeIfPresent([StreakDefinition].self, forKey: .streaks)
            ?? (try container.decodeIfPresent([DailyStreakMilestone].self, forKey: .dailyStreakMilestones) ?? []).map { milestone in
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
            theme: try container.decodeIfPresent(ThemeID.self, forKey: .theme) ?? .coinGarden,
            speechEnabled: try container.decodeIfPresent(Bool.self, forKey: .speechEnabled) ?? false,
            masterPassword: try container.decodeIfPresent(String.self, forKey: .masterPassword) ?? "1234",
            activities: activities,
            comboMilestones: try container.decodeIfPresent([ComboMilestone].self, forKey: .comboMilestones) ?? [],
            streaks: streaks,
            achievements: try container.decodeIfPresent([AchievementDefinition].self, forKey: .achievements) ?? [],
            treasureChest: try container.decodeIfPresent(TreasureChestConfig.self, forKey: .treasureChest) ?? TreasureChestConfig(
                isEnabled: true,
                minDailyStreak: 2,
                minDailyCompletions: 2,
                chance: 0.35,
                minCoins: 3,
                maxCoins: 7
            ),
            economy: try container.decodeIfPresent(EconomyConfig.self, forKey: .economy) ?? EconomyConfig(coinsPerDollar: 20)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(theme, forKey: .theme)
        try container.encode(speechEnabled, forKey: .speechEnabled)
        try container.encode(masterPassword, forKey: .masterPassword)
        try container.encode(activities, forKey: .activities)
        try container.encode(comboMilestones, forKey: .comboMilestones)
        try container.encode(streaks, forKey: .streaks)
        try container.encode(achievements, forKey: .achievements)
        try container.encode(treasureChest, forKey: .treasureChest)
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
        case coinBalance
        case lifetimeCoins
        case dailyStreak
        case dailyCompletionCount
        case currentDayKey
        case lastActiveDayKey
        case suspiciousTapCount
        case cashedOutCoinsWatermark
        case cashedOutDollars
        case activityProgress
        case streakProgress
        case unlockedAchievementIDs
        case ledger
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            coinBalance: try container.decodeIfPresent(Int.self, forKey: .coinBalance) ?? 0,
            lifetimeCoins: try container.decodeIfPresent(Int.self, forKey: .lifetimeCoins) ?? 0,
            dailyStreak: try container.decodeIfPresent(Int.self, forKey: .dailyStreak) ?? 0,
            dailyCompletionCount: try container.decodeIfPresent(Int.self, forKey: .dailyCompletionCount) ?? 0,
            currentDayKey: try container.decodeIfPresent(String.self, forKey: .currentDayKey),
            lastActiveDayKey: try container.decodeIfPresent(String.self, forKey: .lastActiveDayKey),
            suspiciousTapCount: try container.decodeIfPresent(Int.self, forKey: .suspiciousTapCount) ?? 0,
            cashedOutCoinsWatermark: try container.decodeIfPresent(Int.self, forKey: .cashedOutCoinsWatermark) ?? 0,
            cashedOutDollars: try container.decodeIfPresent(Double.self, forKey: .cashedOutDollars) ?? 0,
            activityProgress: try container.decodeIfPresent([String: ActivityProgress].self, forKey: .activityProgress) ?? [:],
            streakProgress: try container.decodeIfPresent([String: StreakProgress].self, forKey: .streakProgress) ?? [:],
            unlockedAchievementIDs: try container.decodeIfPresent(Set<String>.self, forKey: .unlockedAchievementIDs) ?? [],
            ledger: try container.decodeIfPresent([LedgerEntry].self, forKey: .ledger) ?? []
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coinBalance, forKey: .coinBalance)
        try container.encode(lifetimeCoins, forKey: .lifetimeCoins)
        try container.encode(dailyStreak, forKey: .dailyStreak)
        try container.encode(dailyCompletionCount, forKey: .dailyCompletionCount)
        try container.encodeIfPresent(currentDayKey, forKey: .currentDayKey)
        try container.encodeIfPresent(lastActiveDayKey, forKey: .lastActiveDayKey)
        try container.encode(suspiciousTapCount, forKey: .suspiciousTapCount)
        try container.encode(cashedOutCoinsWatermark, forKey: .cashedOutCoinsWatermark)
        try container.encode(cashedOutDollars, forKey: .cashedOutDollars)
        try container.encode(activityProgress, forKey: .activityProgress)
        try container.encode(streakProgress, forKey: .streakProgress)
        try container.encode(unlockedAchievementIDs, forKey: .unlockedAchievementIDs)
        try container.encode(ledger, forKey: .ledger)
    }
}
