import Foundation

enum ThemeID: String, Codable, CaseIterable, Identifiable {
    case coins

    var id: String { rawValue }
}

struct ActivityDefinition: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var detail: String
    var baseReward: Int
    var lockoutSeconds: Int
    var symbol: String
    var repetitionBonusPreset: DailyRepetitionBonusPreset
    var dailyMaximum: Int

    init(
        id: String,
        title: String,
        detail: String,
        baseReward: Int,
        lockoutSeconds: Int,
        symbol: String,
        repetitionBonusPreset: DailyRepetitionBonusPreset = .none,
        dailyMaximum: Int = 20
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.baseReward = baseReward
        self.lockoutSeconds = lockoutSeconds
        self.symbol = symbol
        self.repetitionBonusPreset = repetitionBonusPreset
        self.dailyMaximum = dailyMaximum
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case detail
        case baseReward
        case lockoutSeconds
        case symbol
        case repetitionBonusPreset
        case dailyMaximum
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        detail = try container.decode(String.self, forKey: .detail)
        baseReward = try container.decode(Int.self, forKey: .baseReward)
        lockoutSeconds = try container.decode(Int.self, forKey: .lockoutSeconds)
        symbol = try container.decode(String.self, forKey: .symbol)
        repetitionBonusPreset = try container.decodeIfPresent(
            DailyRepetitionBonusPreset.self,
            forKey: .repetitionBonusPreset
        ) ?? .none
        dailyMaximum = try container.decodeIfPresent(Int.self, forKey: .dailyMaximum) ?? 20
    }
}

enum DailyRepetitionBonusPreset: String, Codable, CaseIterable, Identifiable, Hashable {
    case high3x
    case medium5x
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high3x:
            return "High (3x)"
        case .medium5x:
            return "Medium (5x)"
        case .none:
            return "None"
        }
    }

    var thresholds: [(completionCount: Int, coins: Int)] {
        switch self {
        case .high3x:
            return [(3, 1), (6, 2), (9, 3), (12, 5)]
        case .medium5x:
            return [(5, 1), (10, 2), (15, 3), (20, 5)]
        case .none:
            return []
        }
    }

    func bonusCoins(at completionCount: Int) -> Int? {
        thresholds.first { $0.completionCount == completionCount }?.coins
    }

    func detail(for completionCount: Int) -> String {
        "Completed this activity \(completionCount)x today."
    }
}

struct DailyDefinition: Identifiable, Codable, Hashable {
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
    var symbol: String = "flame.fill"
}

struct EconomyConfig: Codable, Hashable {
    var coinsPerDollar: Double
}

struct GameConfig: Codable, Hashable {
    var theme: ThemeID
    var speechEnabled: Bool
    var masterPassword: String
    var activities: [ActivityDefinition]
    var dailyCompletionBonuses: [DailyDefinition]
    var streaks: [StreakDefinition]
    var economy: EconomyConfig
}

enum RewardKind: String, Codable {
    case structured
    case combo
    case dailyStreak
    case adjustment
    case cashOut
}

struct ActivityEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var createdAt: Date
    var activityID: String
    var activityTitle: String
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
    var activityEvents: [ActivityEvent] = []
    var rewardEvents: [RewardEvent] = []
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
                    symbol: "leaf.fill",
                    repetitionBonusPreset: .high3x,
                    dailyMaximum: 12
                ),
                ActivityDefinition(
                    id: "song-practice",
                    title: "Song Practice",
                    detail: "Run one assigned song from start to finish.",
                    baseReward: 2,
                    lockoutSeconds: 600,
                    symbol: "music.note",
                    repetitionBonusPreset: .medium5x,
                    dailyMaximum: 20
                ),
                ActivityDefinition(
                    id: "sight-reading",
                    title: "Sight Reading",
                    detail: "Try something new without stopping.",
                    baseReward: 2,
                    lockoutSeconds: 600,
                    symbol: "eye.fill",
                    repetitionBonusPreset: .none,
                    dailyMaximum: 5
                )
            ],
            dailyCompletionBonuses: [],
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
