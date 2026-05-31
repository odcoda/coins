import Foundation

enum AchievementCatalog {
    static let all: [AchievementDefinition] = [
        achievement("first-step", "First Step", "Complete your first activity.", .milestones, .totalCompletions(1), 1, "flag.fill"),
        achievement("first-10", "Treasure Hunter", "Complete ten activities total.", .milestones, .totalCompletions(10), 5, "map.fill"),
        achievement("practice-50", "Practice Pro", "Complete fifty activities total.", .milestones, .totalCompletions(50), 10, "medal.fill"),
        achievement("practice-100", "Century Club", "Complete one hundred activities total.", .milestones, .totalCompletions(100), 20, "trophy.fill"),
        achievement("coins-25", "Piggy Bank Builder", "Reach 25 lifetime coins.", .milestones, .lifetimeCoins(25), 5, "banknote.fill"),
        achievement("coins-100", "Treasure Vault", "Reach 100 lifetime coins.", .milestones, .lifetimeCoins(100), 15, "lock.open.fill"),
        achievement("streak-3-days", "Three-Day Glow", "Practice for three days in a row.", .milestones, .dailyStreak(3), 4, "sparkles"),
        achievement("streak-7-days", "Weeklong Shine", "Practice for seven days in a row.", .milestones, .dailyStreak(7), 10, "sun.max.fill"),
        achievement("repeat-12", "Repeat Performer", "Complete one activity twelve times total.", .milestones, .anyActivityCompletions(12), 8, "repeat"),

        achievement("daily-2", "Double Feature", "Complete two activities in one day.", .lessonPatterns, .dailyCompletions(2), 1, "2.circle.fill"),
        achievement("daily-5", "High Five", "Complete five activities in one day.", .lessonPatterns, .dailyCompletions(5), 3, "hand.raised.fill"),
        achievement("daily-7", "Lucky Seven", "Complete seven activities in one day.", .lessonPatterns, .dailyCompletions(7), 5, "7.circle.fill"),
        achievement("variety-3", "Variety Pack", "Complete three different activities in one day.", .lessonPatterns, .distinctActivitiesToday(3), 3, "square.grid.2x2.fill"),
        achievement("full-tour", "Full Tour", "Complete every configured activity in one day.", .lessonPatterns, .allActivitiesToday, 5, "checklist.checked"),
        achievement("lesson-forward", "Straight Through", "Complete the configured activities in order.", .lessonPatterns, .configuredActivitiesInOrderToday, 4, "arrow.right.circle.fill"),
        achievement("lesson-backwards", "Backwards Day", "Complete the configured activities in reverse order.", .lessonPatterns, .configuredActivitiesInReverseOrderToday, 7, "arrow.backward.circle.fill"),
        achievement("encore-3", "Encore Encore", "Complete the same activity three times in a row.", .lessonPatterns, .sameActivityInARow(3), 3, "repeat.circle.fill"),
        achievement("ping-pong-4", "Ping Pong", "Alternate between two activities four times.", .lessonPatterns, .alternatingActivitiesInARow(4), 4, "arrow.left.arrow.right.circle.fill"),
        achievement("round-trip", "Round Trip", "Complete one activity, another one, then the first again.", .lessonPatterns, .roundTrip, 3, "arrow.uturn.backward.circle.fill"),

        achievement("early-bird", "Early Bird", "Complete an activity before 8 AM.", .calendarSurprises, .beforeHour(8), 3, "sunrise.fill"),
        achievement("night-owl", "Night Owl", "Complete an activity at or after 8 PM.", .calendarSurprises, .afterHour(20), 3, "moon.stars.fill"),
        achievement("lunch-break", "Lunch Break", "Complete an activity during the noon hour.", .calendarSurprises, .duringHour(12), 3, "fork.knife"),
        achievement("friday-fanfare", "Friday Fanfare", "Complete an activity on a Friday.", .calendarSurprises, .weekday(6), 3, "music.note.list"),
        achievement("weekend-warrior", "Weekend Warrior", "Complete an activity during the weekend.", .calendarSurprises, .weekend, 3, "calendar"),
        achievement("month-kickoff", "Month Kickoff", "Complete an activity on the first day of a month.", .calendarSurprises, .dayOfMonth(1), 4, "calendar.badge.plus"),
        achievement("month-finale", "Month Finale", "Complete an activity on the last day of a month.", .calendarSurprises, .lastDayOfMonth, 4, "calendar.badge.checkmark"),
        achievement("friday-13", "Friday the Thirteenth", "Brave a practice session on Friday the 13th.", .calendarSurprises, .fridayThe13th, 13, "13.circle.fill"),
        achievement("leap-day", "Leap Day", "Complete an activity on February 29.", .calendarSurprises, .leapDay, 29, "hare.fill"),
        achievement("palindrome-date", "Palindrome Portal", "Complete an activity on a YYYYMMDD palindrome date.", .calendarSurprises, .palindromeDate, 20, "sparkle.magnifyingglass")
    ]

    static let defaultAchievements: [AchievementDefinition] = enabledAchievements(
        withIDs: ["first-10", "coins-25", "repeat-12"]
    )

    static func achievements(in category: AchievementCategory) -> [AchievementDefinition] {
        all.filter { $0.category == category }
    }

    static func enabledAchievements(withIDs ids: some Sequence<String>) -> [AchievementDefinition] {
        let enabledIDs = Set(ids)
        return all.filter { enabledIDs.contains($0.id) }
    }

    private static func achievement(
        _ id: String,
        _ title: String,
        _ detail: String,
        _ category: AchievementCategory,
        _ rule: AchievementRule,
        _ rewardCoins: Int,
        _ symbol: String
    ) -> AchievementDefinition {
        AchievementDefinition(
            id: id,
            title: title,
            detail: detail,
            category: category,
            rule: rule,
            rewardCoins: rewardCoins,
            symbol: symbol
        )
    }
}

struct AchievementEvaluationContext {
    let date: Date
    let calendar: Calendar
    let totalCompletions: Int
    let lifetimeCoins: Int
    let dailyStreak: Int
    let activityIDsToday: [String]
    let distinctActivityIDsToday: Set<String>
    let configuredActivityIDs: [String]
    let activityCompletionCounts: [String: Int]
    let unlockedAchievementIDs: Set<String>

    init(snapshot: GameSnapshot, at date: Date, calendar: Calendar) {
        self.date = date
        self.calendar = calendar
        configuredActivityIDs = snapshot.config.activities.map(\.id)

        let today = calendar.startOfDay(for: date)
        var completionDays: Set<Date> = []
        var activityIDsToday: [String] = []
        var activityCompletionCounts: [String: Int] = [:]

        for event in snapshot.state.activityEvents {
            let eventDay = calendar.startOfDay(for: event.createdAt)
            if eventDay <= today {
                completionDays.insert(eventDay)
            }
            if calendar.isDate(event.createdAt, inSameDayAs: date) {
                activityIDsToday.append(event.activityID)
            }
            activityCompletionCounts[event.activityID, default: 0] += 1
        }

        var lifetimeCoins = 0
        var unlockedAchievementIDs: Set<String> = []
        for event in snapshot.state.rewardEvents {
            lifetimeCoins += max(event.coins, 0)
            if event.kind == .achievement, let definitionID = event.definitionID {
                unlockedAchievementIDs.insert(definitionID)
            }
        }

        totalCompletions = snapshot.state.activityEvents.count
        self.lifetimeCoins = lifetimeCoins
        dailyStreak = Self.dailyStreak(in: completionDays, through: today, calendar: calendar)
        self.activityIDsToday = activityIDsToday
        distinctActivityIDsToday = Set(activityIDsToday)
        self.activityCompletionCounts = activityCompletionCounts
        self.unlockedAchievementIDs = unlockedAchievementIDs
    }

    var dailyCompletions: Int {
        activityIDsToday.count
    }

    var hour: Int {
        calendar.component(.hour, from: date)
    }

    var weekday: Int {
        calendar.component(.weekday, from: date)
    }

    var day: Int {
        calendar.component(.day, from: date)
    }

    var month: Int {
        calendar.component(.month, from: date)
    }

    var isLastDayOfMonth: Bool {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else {
            return false
        }
        return calendar.component(.month, from: tomorrow) != month
    }

    var hasPalindromeDate: Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let digits = String(
            format: "%04d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
        return digits == String(digits.reversed())
    }

    func ends(with activityIDs: [String]) -> Bool {
        guard activityIDs.count >= 2, activityIDsToday.count >= activityIDs.count else {
            return false
        }
        return Array(activityIDsToday.suffix(activityIDs.count)) == activityIDs
    }

    func hasSameActivityInARow(count: Int) -> Bool {
        guard count >= 2, activityIDsToday.count >= count else {
            return false
        }
        return Set(activityIDsToday.suffix(count)).count == 1
    }

    func hasAlternatingActivitiesInARow(count: Int) -> Bool {
        guard count >= 4, activityIDsToday.count >= count else {
            return false
        }

        let recent = Array(activityIDsToday.suffix(count))
        guard recent[0] != recent[1] else {
            return false
        }
        return recent.indices.allSatisfy { recent[$0] == recent[$0 % 2] }
    }

    var hasRoundTrip: Bool {
        guard activityIDsToday.count >= 3 else {
            return false
        }
        let recent = Array(activityIDsToday.suffix(3))
        return recent[0] == recent[2] && recent[0] != recent[1]
    }

    private static func dailyStreak(in completionDays: Set<Date>, through today: Date, calendar: Calendar) -> Int {
        let sortedDays = completionDays.sorted()
        guard let latestDay = sortedDays.last else {
            return 0
        }

        let latestGap = calendar.dateComponents([.day], from: latestDay, to: today).day ?? 0
        guard latestGap <= 1 else {
            return 0
        }

        var streak = 1
        var currentDay = latestDay
        for priorDay in sortedDays.dropLast().reversed() {
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

extension AchievementRule {
    func isSatisfied(in context: AchievementEvaluationContext) -> Bool {
        switch self {
        case .totalCompletions(let count):
            return context.totalCompletions >= count
        case .lifetimeCoins(let coins):
            return context.lifetimeCoins >= coins
        case .dailyStreak(let days):
            return context.dailyStreak >= days
        case .anyActivityCompletions(let count):
            return context.activityCompletionCounts.values.contains { $0 >= count }
        case .dailyCompletions(let count):
            return context.dailyCompletions >= count
        case .distinctActivitiesToday(let count):
            return context.distinctActivityIDsToday.count >= count
        case .allActivitiesToday:
            return !context.configuredActivityIDs.isEmpty
                && Set(context.configuredActivityIDs).isSubset(of: context.distinctActivityIDsToday)
        case .configuredActivitiesInOrderToday:
            return context.ends(with: context.configuredActivityIDs)
        case .configuredActivitiesInReverseOrderToday:
            return context.ends(with: Array(context.configuredActivityIDs.reversed()))
        case .sameActivityInARow(let count):
            return context.hasSameActivityInARow(count: count)
        case .alternatingActivitiesInARow(let count):
            return context.hasAlternatingActivitiesInARow(count: count)
        case .roundTrip:
            return context.hasRoundTrip
        case .beforeHour(let hour):
            return context.hour < hour
        case .afterHour(let hour):
            return context.hour >= hour
        case .duringHour(let hour):
            return context.hour == hour
        case .weekday(let weekday):
            return context.weekday == weekday
        case .weekend:
            return context.calendar.isDateInWeekend(context.date)
        case .dayOfMonth(let day):
            return context.day == day
        case .lastDayOfMonth:
            return context.isLastDayOfMonth
        case .fridayThe13th:
            return context.weekday == 6 && context.day == 13
        case .leapDay:
            return context.month == 2 && context.day == 29
        case .palindromeDate:
            return context.hasPalindromeDate
        }
    }
}
