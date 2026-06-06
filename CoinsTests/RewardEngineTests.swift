import XCTest
@testable import Coins

final class RewardEngineTests: XCTestCase {
    func testLockoutBlocksRapidTaps() {
        var snapshot = GameSnapshot.seed
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let first = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: now)
        let second = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: now.addingTimeInterval(30))

        XCTAssertFalse(first.isDenied)
        XCTAssertTrue(second.isDenied)
        XCTAssertEqual(snapshot.state.activityEvents.count, 1)
        XCTAssertEqual(snapshot.state.rewardEvents, first.events)
    }

    func testRepetitionPresetAndConfiguredDailyStreakRewardsStack() {
        var snapshot = GameSnapshot.seed
        let calendar = Calendar(identifier: .gregorian)
        let dayOne = Date(timeIntervalSince1970: 1_700_000_000)
        let dayTwo = dayOne.addingTimeInterval(86_400)
        let dayThree = dayTwo.addingTimeInterval(86_400)

        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: dayOne, calendar: calendar)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: dayOne.addingTimeInterval(301), calendar: calendar)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: dayOne.addingTimeInterval(602), calendar: calendar)
        _ = RewardEngine.complete(activityID: "song-practice", snapshot: &snapshot, now: dayTwo, calendar: calendar)
        let result = RewardEngine.complete(activityID: "sight-reading", snapshot: &snapshot, now: dayThree, calendar: calendar)

        XCTAssertEqual(snapshot.state.activeDailyStreak(at: dayThree, calendar: calendar), 3)
        XCTAssertTrue(result.events.contains(where: { $0.kind == .dailyStreak && $0.coins == 4 }))
        XCTAssertTrue(snapshot.state.rewardEvents.contains(where: { $0.kind == .combo }))
    }

    func testMediumRepetitionPresetAwardsAtConfiguredThresholds() {
        var snapshot = GameSnapshot.seed
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        snapshot.config.activities[1].lockoutSeconds = 0

        var results: [CompletionResult] = []
        for offset in 0..<10 {
            results.append(
                RewardEngine.complete(
                    activityID: "song-practice",
                    snapshot: &snapshot,
                    now: start.addingTimeInterval(Double(offset)),
                    calendar: calendar
                )
            )
        }

        XCTAssertTrue(results[4].events.contains(where: { $0.kind == .combo && $0.coins == 1 }))
        XCTAssertTrue(results[9].events.contains(where: { $0.kind == .combo && $0.coins == 2 }))
        XCTAssertFalse(results[0].events.contains(where: { $0.kind == .combo }))
    }

    func testDailyMaximumBlocksAdditionalCompletionsUntilNextDay() {
        var snapshot = GameSnapshot.seed
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        snapshot.config.activities[0].lockoutSeconds = 0
        snapshot.config.activities[0].dailyMaximum = 1

        let first = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: start, calendar: calendar)
        let second = RewardEngine.complete(
            activityID: "warmup",
            snapshot: &snapshot,
            now: start.addingTimeInterval(60),
            calendar: calendar
        )
        let nextDay = RewardEngine.complete(
            activityID: "warmup",
            snapshot: &snapshot,
            now: start.addingTimeInterval(86_400),
            calendar: calendar
        )

        XCTAssertFalse(first.isDenied)
        XCTAssertTrue(second.isDenied)
        XCTAssertEqual(second.deniedReason, "Daily maximum reached for Warm-Up.")
        XCTAssertFalse(nextDay.isDenied)
        XCTAssertEqual(snapshot.state.activityEvents.count, 2)
    }

    func testWeeklyStreakExtraRewardGrowsAfterMinimum() {
        var snapshot = GameSnapshot.seed
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

        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: weekOne, calendar: calendar)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: weekTwo, calendar: calendar)
        let third = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: weekThree, calendar: calendar)
        let fourth = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: weekFour, calendar: calendar)

        XCTAssertTrue(third.events.contains(where: { $0.kind == .dailyStreak && $0.coins == 3 }))
        XCTAssertTrue(fourth.events.contains(where: { $0.kind == .dailyStreak && $0.coins == 4 }))
        XCTAssertEqual(
            RewardEngine.streakLength(for: snapshot.config.streaks[0], snapshot: snapshot, at: weekFour, calendar: calendar),
            4
        )
    }

    func testEveryTwoDaysStreakUsesTwoDayPeriods() {
        var snapshot = GameSnapshot.seed
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

        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: dayOne, calendar: calendar)
        let second = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: samePeriod, calendar: calendar)
        let third = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: nextPeriod, calendar: calendar)

        XCTAssertFalse(second.events.contains(where: { $0.kind == .dailyStreak }))
        XCTAssertTrue(third.events.contains(where: { $0.kind == .dailyStreak && $0.coins == 4 }))
        XCTAssertEqual(
            RewardEngine.streakLength(for: snapshot.config.streaks[0], snapshot: snapshot, at: nextPeriod, calendar: calendar),
            2
        )
    }

    func testStreakIgnoresActivitiesOutsideConfiguredSet() {
        var snapshot = GameSnapshot.seed
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

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let result = RewardEngine.complete(activityID: "song-practice", snapshot: &snapshot, now: now)

        XCTAssertFalse(result.events.contains(where: { $0.kind == .dailyStreak }))
        XCTAssertEqual(
            RewardEngine.streakLength(for: snapshot.config.streaks[0], snapshot: snapshot, at: now),
            0
        )
    }

    func testCashOutUsesWatermarkInsteadOfReducingBalance() {
        var snapshot = GameSnapshot.seed
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        _ = RewardEngine.complete(activityID: "song-practice", snapshot: &snapshot, now: start)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: start.addingTimeInterval(301))

        let cashOut = RewardEngine.cashOut(snapshot: &snapshot, now: start.addingTimeInterval(600))
        let secondCashOut = RewardEngine.cashOut(snapshot: &snapshot, now: start.addingTimeInterval(900))

        XCTAssertNotNil(cashOut)
        XCTAssertEqual(snapshot.state.coinBalance, 3)
        XCTAssertNil(secondCashOut)
        XCTAssertEqual(snapshot.state.cashedOutCoinsWatermark, 3)
        XCTAssertEqual(snapshot.state.cashedOutDollars, 0.15, accuracy: 0.0001)
    }

    func testCompletionRecordsActivityHistoryAndRewardProvenance() {
        var snapshot = GameSnapshot.seed
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let result = RewardEngine.complete(activityID: "song-practice", snapshot: &snapshot, now: now)

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
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: now)

        let rewind = RewardEngine.adjustCoins(snapshot: &snapshot, delta: -5, reason: "Correction")

        XCTAssertEqual(rewind?.coins, -1)
        XCTAssertEqual(snapshot.state.coinBalance, 0)
    }

    func testSnapshotRoundTripPreservesEventHistories() throws {
        var snapshot = GameSnapshot.seed
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: now)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: now.addingTimeInterval(30))

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        XCTAssertEqual(try decoder.decode(GameSnapshot.self, from: data), snapshot)
    }
}
