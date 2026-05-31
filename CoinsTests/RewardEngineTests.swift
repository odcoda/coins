import XCTest
import UIKit
@testable import Coins

final class RewardEngineTests: XCTestCase {
    func testLockoutBlocksRapidTaps() {
        var snapshot = GameSnapshot.seed
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let first = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: now, roll: 1)
        let second = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: now.addingTimeInterval(30), roll: 1)

        XCTAssertFalse(first.isDenied)
        XCTAssertTrue(second.isDenied)
        XCTAssertEqual(snapshot.state.activityEvents.count, 1)
        XCTAssertEqual(snapshot.state.rewardEvents, first.events)
    }

    func testComboAndConfiguredDailyStreakRewardsStack() {
        var snapshot = GameSnapshot.seed
        let calendar = Calendar(identifier: .gregorian)
        let dayOne = Date(timeIntervalSince1970: 1_700_000_000)
        let dayTwo = dayOne.addingTimeInterval(86_400)
        let dayThree = dayTwo.addingTimeInterval(86_400)

        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: dayOne, roll: 1, calendar: calendar)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: dayOne.addingTimeInterval(301), roll: 1, calendar: calendar)
        _ = RewardEngine.complete(activityID: "song-practice", snapshot: &snapshot, now: dayTwo, roll: 1, calendar: calendar)
        let result = RewardEngine.complete(activityID: "sight-reading", snapshot: &snapshot, now: dayThree, roll: 1, calendar: calendar)

        XCTAssertEqual(snapshot.state.activeDailyStreak(at: dayThree, calendar: calendar), 3)
        XCTAssertTrue(result.events.contains(where: { $0.kind == .dailyStreak && $0.coins == 4 }))
        XCTAssertTrue(snapshot.state.rewardEvents.contains(where: { $0.kind == .combo }))
    }

    func testWeeklyStreakExtraRewardGrowsAfterMinimum() {
        var snapshot = GameSnapshot.seed
        snapshot.config.randomDrops.isEnabled = false
        snapshot.config.streaks = [
            StreakDefinition(
                id: "weekly-practice",
                title: "Weekly Practice",
                detail: "Practice every week.",
                activityIDs: ["warmup"],
                frequency: .weekly,
                minimumLength: 3,
                rewardCoins: 3,
                extraRewardCoins: 1
            )
        ]

        let calendar = Calendar(identifier: .gregorian)
        let weekOne = Date(timeIntervalSince1970: 1_700_000_000)
        let weekTwo = weekOne.addingTimeInterval(7 * 86_400)
        let weekThree = weekTwo.addingTimeInterval(7 * 86_400)
        let weekFour = weekThree.addingTimeInterval(7 * 86_400)

        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: weekOne, roll: 1, calendar: calendar)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: weekTwo, roll: 1, calendar: calendar)
        let third = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: weekThree, roll: 1, calendar: calendar)
        let fourth = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: weekFour, roll: 1, calendar: calendar)

        XCTAssertTrue(third.events.contains(where: { $0.kind == .dailyStreak && $0.coins == 3 }))
        XCTAssertTrue(fourth.events.contains(where: { $0.kind == .dailyStreak && $0.coins == 4 }))
        XCTAssertEqual(
            RewardEngine.streakLength(for: snapshot.config.streaks[0], snapshot: snapshot, at: weekFour, calendar: calendar),
            4
        )
    }

    func testEveryTwoDaysStreakUsesTwoDayPeriods() {
        var snapshot = GameSnapshot.seed
        snapshot.config.randomDrops.isEnabled = false
        snapshot.config.streaks = [
            StreakDefinition(
                id: "every-two-days",
                title: "Every Two Days",
                detail: "Practice every other day.",
                activityIDs: ["warmup"],
                frequency: .every2Days,
                minimumLength: 2,
                rewardCoins: 4,
                extraRewardCoins: 0
            )
        ]

        let calendar = Calendar(identifier: .gregorian)
        let dayOne = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let samePeriod = dayOne.addingTimeInterval(86_400)
        let nextPeriod = dayOne.addingTimeInterval(2 * 86_400)

        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: dayOne, roll: 1, calendar: calendar)
        let second = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: samePeriod, roll: 1, calendar: calendar)
        let third = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: nextPeriod, roll: 1, calendar: calendar)

        XCTAssertFalse(second.events.contains(where: { $0.kind == .dailyStreak }))
        XCTAssertTrue(third.events.contains(where: { $0.kind == .dailyStreak && $0.coins == 4 }))
        XCTAssertEqual(
            RewardEngine.streakLength(for: snapshot.config.streaks[0], snapshot: snapshot, at: nextPeriod, calendar: calendar),
            2
        )
    }

    func testStreakIgnoresActivitiesOutsideConfiguredSet() {
        var snapshot = GameSnapshot.seed
        snapshot.config.randomDrops.isEnabled = false
        snapshot.config.streaks = [
            StreakDefinition(
                id: "warmup-only",
                title: "Warm-Up Only",
                detail: "Only warm-ups count.",
                activityIDs: ["warmup"],
                frequency: .daily,
                minimumLength: 1,
                rewardCoins: 2,
                extraRewardCoins: 0
            )
        ]

        let result = RewardEngine.complete(
            activityID: "song-practice",
            snapshot: &snapshot,
            now: Date(timeIntervalSince1970: 1_700_000_000),
            roll: 1
        )

        XCTAssertFalse(result.events.contains(where: { $0.kind == .dailyStreak }))
        XCTAssertEqual(
            RewardEngine.streakLength(
                for: snapshot.config.streaks[0],
                snapshot: snapshot,
                at: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            0
        )
    }

    func testCashOutUsesWatermarkInsteadOfReducingBalance() {
        var snapshot = GameSnapshot.seed
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        _ = RewardEngine.complete(activityID: "song-practice", snapshot: &snapshot, now: start, roll: 1)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: start.addingTimeInterval(301), roll: 1)

        let cashOut = RewardEngine.cashOut(snapshot: &snapshot, now: start.addingTimeInterval(600))
        let secondCashOut = RewardEngine.cashOut(snapshot: &snapshot, now: start.addingTimeInterval(900))

        XCTAssertNotNil(cashOut)
        XCTAssertEqual(snapshot.state.coinBalance, 4)
        XCTAssertNil(secondCashOut)
        XCTAssertEqual(snapshot.state.cashedOutCoinsWatermark, 4)
        XCTAssertEqual(snapshot.state.cashedOutDollars, 0.2, accuracy: 0.0001)
    }

    func testCompletionRecordsActivityHistoryAndRewardProvenance() {
        var snapshot = GameSnapshot.seed
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let result = RewardEngine.complete(activityID: "song-practice", snapshot: &snapshot, now: now, roll: 1)

        XCTAssertEqual(snapshot.state.activityEvents.count, 1)
        XCTAssertEqual(snapshot.state.activityEvents[0].activityID, "song-practice")
        XCTAssertEqual(snapshot.state.activityEvents[0].activityTitle, "Song Practice")
        XCTAssertEqual(snapshot.state.activityEvents[0].createdAt, now)
        XCTAssertEqual(result.events.first?.activityEventID, snapshot.state.activityEvents[0].id)
        XCTAssertEqual(snapshot.state.rewardEvents, result.events)
    }

    func testRewindRecordsActualDeltaWithoutTakingBalanceNegative() {
        var snapshot = GameSnapshot.seed
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: now, roll: 1)

        let rewind = RewardEngine.adjustCoins(snapshot: &snapshot, delta: -5, reason: "Correction")

        XCTAssertEqual(rewind?.coins, -1)
        XCTAssertEqual(snapshot.state.coinBalance, 0)
    }

    func testSnapshotRoundTripPreservesEventHistories() throws {
        var snapshot = GameSnapshot.seed
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: now, roll: 1)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: now.addingTimeInterval(30), roll: 1)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        XCTAssertEqual(try decoder.decode(GameSnapshot.self, from: data), snapshot)
    }

    func testMalformedRandomDropBoundsAreClamped() {
        var snapshot = GameSnapshot.seed
        snapshot.config.randomDrops.minDailyStreak = 1
        snapshot.config.randomDrops.minDailyCompletions = 1
        snapshot.config.randomDrops.chance = 2
        snapshot.config.randomDrops.minCoins = 5
        snapshot.config.randomDrops.maxCoins = -1

        let result = RewardEngine.complete(
            activityID: "warmup",
            snapshot: &snapshot,
            now: Date(timeIntervalSince1970: 1_700_000_000),
            roll: 1
        )

        XCTAssertTrue(result.events.contains(where: { $0.kind == .treasureChest && $0.coins == 5 }))
    }

    func testAchievementCatalogHasManySpecialOptions() {
        XCTAssertGreaterThanOrEqual(AchievementCatalog.all.count, 20)
        XCTAssertTrue(AchievementCatalog.all.contains { $0.rule == .configuredActivitiesInReverseOrderToday })
        XCTAssertTrue(AchievementCatalog.all.contains { $0.rule == .fridayThe13th })
        XCTAssertTrue(AchievementCatalog.all.contains { $0.rule == .palindromeDate })
        for achievement in AchievementCatalog.all {
            XCTAssertNotNil(UIImage(systemName: achievement.symbol), achievement.symbol)
        }
    }

    func testReverseLessonAchievementUnlocksFromTodaysActivityOrder() {
        var snapshot = snapshotWithAchievement("lesson-backwards")
        let calendar = Calendar(identifier: .gregorian)
        let start = date(year: 2026, month: 5, day: 15, hour: 15, calendar: calendar)

        _ = RewardEngine.complete(activityID: "sight-reading", snapshot: &snapshot, now: start, roll: 1, calendar: calendar)
        _ = RewardEngine.complete(activityID: "song-practice", snapshot: &snapshot, now: start.addingTimeInterval(60), roll: 1, calendar: calendar)
        let result = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: start.addingTimeInterval(120), roll: 1, calendar: calendar)

        XCTAssertTrue(result.events.contains { $0.kind == .achievement && $0.definitionID == "lesson-backwards" })
    }

    func testReverseLessonAchievementDoesNotUsePriorDayEvents() {
        var snapshot = snapshotWithAchievement("lesson-backwards")
        let calendar = Calendar(identifier: .gregorian)
        let dayOne = date(year: 2026, month: 5, day: 15, hour: 15, calendar: calendar)
        let dayTwo = date(year: 2026, month: 5, day: 16, hour: 15, calendar: calendar)

        _ = RewardEngine.complete(activityID: "sight-reading", snapshot: &snapshot, now: dayOne, roll: 1, calendar: calendar)
        _ = RewardEngine.complete(activityID: "song-practice", snapshot: &snapshot, now: dayTwo, roll: 1, calendar: calendar)
        let result = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: dayTwo.addingTimeInterval(60), roll: 1, calendar: calendar)

        XCTAssertFalse(result.events.contains { $0.kind == .achievement && $0.definitionID == "lesson-backwards" })
    }

    func testFridayTheThirteenthAchievementUnlocks() {
        var snapshot = snapshotWithAchievement("friday-13")
        let calendar = Calendar(identifier: .gregorian)
        let fridayTheThirteenth = date(year: 2024, month: 9, day: 13, hour: 15, calendar: calendar)

        let result = RewardEngine.complete(
            activityID: "warmup",
            snapshot: &snapshot,
            now: fridayTheThirteenth,
            roll: 1,
            calendar: calendar
        )

        XCTAssertTrue(result.events.contains { $0.kind == .achievement && $0.definitionID == "friday-13" && $0.coins == 13 })
    }

    func testDisabledAchievementDoesNotUnlock() {
        var snapshot = snapshotWithAchievement(nil)
        let calendar = Calendar(identifier: .gregorian)
        let fridayTheThirteenth = date(year: 2024, month: 9, day: 13, hour: 15, calendar: calendar)

        let result = RewardEngine.complete(
            activityID: "warmup",
            snapshot: &snapshot,
            now: fridayTheThirteenth,
            roll: 1,
            calendar: calendar
        )

        XCTAssertFalse(result.events.contains { $0.kind == .achievement })
    }

    private func snapshotWithAchievement(_ id: String?) -> GameSnapshot {
        var snapshot = GameSnapshot.seed
        snapshot.config.dailyCompletionBonuses = []
        snapshot.config.streaks = []
        snapshot.config.randomDrops.isEnabled = false
        snapshot.config.achievements = id.map { AchievementCatalog.enabledAchievements(withIDs: [$0]) } ?? []
        return snapshot
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
