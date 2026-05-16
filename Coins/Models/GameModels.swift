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
    var dailyStreakMilestones: [DailyStreakMilestone]
    var achievements: [AchievementDefinition]
    var treasureChest: TreasureChestConfig
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
    var unlockedAchievementIDs: Set<String> = []
    var ledger: [LedgerEntry] = []
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
                    lockoutSeconds: 900,
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
            dailyStreakMilestones: [
                DailyStreakMilestone(id: "streak-3", days: 3, bonusCoins: 4, title: "Three-Day Spark"),
                DailyStreakMilestone(id: "streak-7", days: 7, bonusCoins: 10, title: "Weeklong Shine")
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

