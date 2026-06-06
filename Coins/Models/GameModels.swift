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
            return "High (3/6/9/12x -> 1/2/3/5c)"
        case .medium5x:
            return "Medium (5/10/15/20x -> 1/2/3/5c)"
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

enum StreakBonusPreset: String, Codable, CaseIterable, Identifiable {
    case noBreaks
    case breaks

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noBreaks:
            return "No Breaks"
        case .breaks:
            return "Breaks"
        }
    }

    var levels: [StreakBonusLevel] {
        switch self {
        case .noBreaks:
            return [
                StreakBonusLevel(days: 2, rewardCoins: 1, breakAllowance: 0),
                StreakBonusLevel(days: 3, rewardCoins: 2, breakAllowance: 0),
                StreakBonusLevel(days: 5, rewardCoins: 3, breakAllowance: 0),
                StreakBonusLevel(days: 7, rewardCoins: 5, breakAllowance: 0)
            ]
        case .breaks:
            return [
                StreakBonusLevel(days: 2, rewardCoins: 1, breakAllowance: 0),
                StreakBonusLevel(days: 3, rewardCoins: 2, breakAllowance: 0),
                StreakBonusLevel(days: 5, rewardCoins: 3, breakAllowance: 1),
                StreakBonusLevel(days: 7, rewardCoins: 5, breakAllowance: 1)
            ]
        }
    }
}

struct StreakBonusLevel: Codable, Hashable {
    var days: Int
    var rewardCoins: Int
    var breakAllowance: Int
}

struct StreakDefinition: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var detail: String
    var activityIDs: [String]
    var dailyMinimum: Int
    var bonusPreset: StreakBonusPreset
    var symbol: String = "flame.fill"
}

struct EconomyConfig: Codable, Hashable {
    var coinsPerCashOutAmount: Int
    var cashOutCents: Int

    init(coinsPerCashOutAmount: Int = 5, cashOutCents: Int = 1) {
        self.coinsPerCashOutAmount = max(coinsPerCashOutAmount, 1)
        self.cashOutCents = max(cashOutCents, 1)
    }

    var cashOutDollars: Double {
        Double(cashOutCents) / 100
    }

    func dollars(for coins: Int) -> Double {
        Double(max(coins, 0)) * cashOutDollars / Double(max(coinsPerCashOutAmount, 1))
    }

    private enum CodingKeys: String, CodingKey {
        case coinsPerCashOutAmount
        case cashOutCents
        case coinsPerDollar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let coinsPerCashOutAmount = try container.decodeIfPresent(Int.self, forKey: .coinsPerCashOutAmount),
           let cashOutCents = try container.decodeIfPresent(Int.self, forKey: .cashOutCents) {
            self.init(coinsPerCashOutAmount: coinsPerCashOutAmount, cashOutCents: cashOutCents)
        } else if let oldCoinsPerDollar = try container.decodeIfPresent(Double.self, forKey: .coinsPerDollar) {
            self.init(coinsPerCashOutAmount: Int(oldCoinsPerDollar.rounded()), cashOutCents: 100)
        } else {
            self.init()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coinsPerCashOutAmount, forKey: .coinsPerCashOutAmount)
        try container.encode(cashOutCents, forKey: .cashOutCents)
    }
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

enum ActivityEventOccurrence: Hashable {
    case timestamp(Date)
    case manuallyAdded(day: Date)

    var effectiveDate: Date {
        switch self {
        case .timestamp(let date), .manuallyAdded(let date):
            return date
        }
    }

    var timestamp: Date? {
        switch self {
        case .timestamp(let date):
            return date
        case .manuallyAdded:
            return nil
        }
    }

    var isManuallyAdded: Bool {
        timestamp == nil
    }
}

extension ActivityEventOccurrence: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case date
        case day
    }

    private enum Kind: String, Codable {
        case timestamp
        case manuallyAdded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .timestamp:
            self = .timestamp(try container.decode(Date.self, forKey: .date))
        case .manuallyAdded:
            self = .manuallyAdded(day: try container.decode(Date.self, forKey: .day))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .timestamp(let date):
            try container.encode(Kind.timestamp, forKey: .kind)
            try container.encode(date, forKey: .date)
        case .manuallyAdded(let day):
            try container.encode(Kind.manuallyAdded, forKey: .kind)
            try container.encode(day, forKey: .day)
        }
    }
}

struct ActivityEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var occurrence: ActivityEventOccurrence
    var activityID: String
    var activityTitle: String

    var createdAt: Date {
        occurrence.effectiveDate
    }

    var timestamp: Date? {
        occurrence.timestamp
    }

    var isManuallyAdded: Bool {
        occurrence.isManuallyAdded
    }

    init(
        id: UUID,
        occurrence: ActivityEventOccurrence,
        activityID: String,
        activityTitle: String
    ) {
        self.id = id
        self.occurrence = occurrence
        self.activityID = activityID
        self.activityTitle = activityTitle
    }

    init(
        id: UUID,
        createdAt: Date,
        activityID: String,
        activityTitle: String
    ) {
        self.init(
            id: id,
            occurrence: .timestamp(createdAt),
            activityID: activityID,
            activityTitle: activityTitle
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case occurrence
        case createdAt
        case activityID
        case activityTitle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        if let occurrence = try container.decodeIfPresent(ActivityEventOccurrence.self, forKey: .occurrence) {
            self.occurrence = occurrence
        } else {
            self.occurrence = .timestamp(try container.decode(Date.self, forKey: .createdAt))
        }
        activityID = try container.decode(String.self, forKey: .activityID)
        activityTitle = try container.decode(String.self, forKey: .activityTitle)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(occurrence, forKey: .occurrence)
        try container.encode(activityID, forKey: .activityID)
        try container.encode(activityTitle, forKey: .activityTitle)
    }
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

struct StreakProgress: Identifiable, Codable, Hashable {
    var streakID: String
    var levelDays: Int
    var lastUpdatedAt: Date

    var id: String { streakID }
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

struct ActivityHistoryDay: Identifiable, Hashable {
    var date: Date
    var countsByActivityID: [String: Int]

    var id: Date {
        date
    }

    var totalCount: Int {
        countsByActivityID.values.reduce(0, +)
    }
}

enum HistoryRewardEstimator {
    static func coins(for countsByActivityID: [String: Int], activities: [ActivityDefinition]) -> Int {
        activities.reduce(0) { total, activity in
            let count = min(max(countsByActivityID[activity.id, default: 0], 0), 50)
            let structuredRewards = count * activity.baseReward
            let repetitionRewards = activity.repetitionBonusPreset.thresholds.reduce(0) { bonusTotal, threshold in
                threshold.completionCount <= count ? bonusTotal + threshold.coins : bonusTotal
            }
            return total + structuredRewards + repetitionRewards
        }
    }

    static func delta(
        from originalCounts: [String: Int],
        to newCounts: [String: Int],
        activities: [ActivityDefinition]
    ) -> Int {
        coins(for: newCounts, activities: activities) - coins(for: originalCounts, activities: activities)
    }
}

struct GameState: Codable, Hashable {
    var activityEvents: [ActivityEvent] = []
    var rewardEvents: [RewardEvent] = []
    var streakProgress: [StreakProgress] = []
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
                    id: "concert-piece",
                    title: "Concert Piece",
                    detail: "See the Little Monkey",
                    baseReward: 1,
                    lockoutSeconds: 30,
                    symbol: "music.note",
                    repetitionBonusPreset: .high3x,
                    dailyMaximum: 20
                ),
                ActivityDefinition(
                    id: "review-piece",
                    title: "Review Piece",
                    detail: "anything from Bunny Ballads",
                    baseReward: 1,
                    lockoutSeconds: 30,
                    symbol: "music.note",
                    repetitionBonusPreset: .medium5x,
                    dailyMaximum: 20
                ),
                ActivityDefinition(
                    id: "violin-exercise",
                    title: "Violin Exercise",
                    detail: "bow or fingers, full set of exercises",
                    baseReward: 2,
                    lockoutSeconds: 30,
                    symbol: "eye.fill",
                    repetitionBonusPreset: .none,
                    dailyMaximum: 2
                ),
                ActivityDefinition(
                    id: "piano-piece",
                    title: "Piano Piece",
                    detail: "any recent piece from Piano Adventures Primer",
                    baseReward: 1,
                    lockoutSeconds: 30,
                    symbol: "music.note",
                    repetitionBonusPreset: .medium5x,
                    dailyMaximum: 20
                ),
            ],
            dailyCompletionBonuses: [],
            streaks: [
                StreakDefinition(
                    id: "streak-violin",
                    title: "Violin Streak",
                    detail: "practice, practice, practice!",
                    activityIDs: ["concert-piece", "review-piece"],
                    dailyMinimum: 3,
                    bonusPreset: .breaks,
                    symbol: "sparkles"
                ),
                StreakDefinition(
                    id: "streak-piano",
                    title: "Piano Streak",
                    detail: "practice, practice, practice!",
                    activityIDs: ["piano-piece"],
                    dailyMinimum: 3,
                    bonusPreset: .breaks,
                    symbol: "sparkles"
                ),
            ],
            economy: EconomyConfig()
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

    var highestStreakLevel: Int {
        streakProgress.map(\.levelDays).max() ?? 0
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

    func activityCountsByDay(
        endingAt endDate: Date,
        days: Int = 30,
        calendar: Calendar = .current
    ) -> [ActivityHistoryDay] {
        let clampedDays = max(days, 1)
        let endDay = calendar.startOfDay(for: endDate)
        return (0..<clampedDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -(clampedDays - 1 - offset), to: endDay) else {
                return nil
            }
            return ActivityHistoryDay(date: day, countsByActivityID: activityCounts(on: day, calendar: calendar))
        }
    }

    func activityCounts(on date: Date, calendar: Calendar = .current) -> [String: Int] {
        var counts: [String: Int] = [:]
        for event in activityEvents where calendar.isDate(event.createdAt, inSameDayAs: date) {
            counts[event.activityID, default: 0] += 1
        }
        return counts
    }

    mutating func rewriteActivityHistory(
        on date: Date,
        countsByActivityID targetCounts: [String: Int],
        activities: [ActivityDefinition],
        calendar: Calendar = .current
    ) {
        let day = calendar.startOfDay(for: date)
        let validActivityIDs = Set(activities.map(\.id))

        for activity in activities {
            let targetCount = min(max(targetCounts[activity.id, default: 0], 0), 50)
            let matchingIndices = activityEvents.indices.filter { index in
                let event = activityEvents[index]
                return event.activityID == activity.id && calendar.isDate(event.createdAt, inSameDayAs: day)
            }
            let delta = targetCount - matchingIndices.count

            if delta < 0 {
                let removalIDs = matchingIndices
                    .map { activityEvents[$0] }
                    .sorted { lhs, rhs in
                        switch (lhs.timestamp, rhs.timestamp) {
                        case let (lhsDate?, rhsDate?):
                            return lhsDate > rhsDate
                        case (_?, nil):
                            return true
                        case (nil, _?):
                            return false
                        case (nil, nil):
                            return lhs.id.uuidString > rhs.id.uuidString
                        }
                    }
                    .prefix(-delta)
                    .map(\.id)
                let removalIDSet = Set(removalIDs)
                activityEvents.removeAll { removalIDSet.contains($0.id) }
            } else if delta > 0 {
                for _ in 0..<delta {
                    activityEvents.append(
                        ActivityEvent(
                            id: UUID(),
                            occurrence: .manuallyAdded(day: day),
                            activityID: activity.id,
                            activityTitle: activity.title
                        )
                    )
                }
            }
        }

        activityEvents.removeAll { event in
            calendar.isDate(event.createdAt, inSameDayAs: day) && !validActivityIDs.contains(event.activityID)
        }
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

    func streakLevel(for streakID: String) -> Int {
        streakProgress.first(where: { $0.streakID == streakID })?.levelDays ?? 0
    }

    mutating func setStreakLevel(_ levelDays: Int, for streakID: String, at date: Date) {
        let progress = StreakProgress(streakID: streakID, levelDays: max(levelDays, 0), lastUpdatedAt: date)
        if let index = streakProgress.firstIndex(where: { $0.streakID == streakID }) {
            streakProgress[index] = progress
        } else {
            streakProgress.append(progress)
        }
    }
}
