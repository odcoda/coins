import XCTest
@testable import Coins

final class RewardEngineTests: XCTestCase {
    func testLockoutBlocksRapidTaps() {
        var snapshot = GameSnapshot.seed
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let first = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: now, roll: 1)
        let second = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: now.addingTimeInterval(30), roll: 1)

        XCTAssertFalse(first.isDenied)
        XCTAssertTrue(second.isDenied)
        XCTAssertEqual(snapshot.state.suspiciousTapCount, 1)
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

        XCTAssertEqual(snapshot.state.dailyStreak, 3)
        XCTAssertTrue(result.events.contains(where: { $0.kind == .dailyStreak && $0.coins == 4 }))
        XCTAssertTrue(snapshot.state.ledger.contains(where: { $0.kind == .combo }))
    }

    func testWeeklyStreakExtraRewardGrowsAfterMinimum() {
        var snapshot = GameSnapshot.seed
        snapshot.config.treasureChest.isEnabled = false
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
        XCTAssertEqual(snapshot.state.streakProgress["weekly-practice"]?.currentLength, 4)
    }

    func testEveryTwoDaysStreakUsesTwoDayPeriods() {
        var snapshot = GameSnapshot.seed
        snapshot.config.treasureChest.isEnabled = false
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
        XCTAssertEqual(snapshot.state.streakProgress["every-two-days"]?.currentLength, 2)
    }

    func testStreakIgnoresActivitiesOutsideConfiguredSet() {
        var snapshot = GameSnapshot.seed
        snapshot.config.treasureChest.isEnabled = false
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
        XCTAssertNil(snapshot.state.streakProgress["warmup-only"])
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
}
