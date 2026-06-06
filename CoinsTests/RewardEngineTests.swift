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

    func testComboAndConfiguredDailyStreakRewardsStack() {
        var snapshot = GameSnapshot.seed
        let calendar = Calendar(identifier: .gregorian)
        let dayOne = Date(timeIntervalSince1970: 1_700_000_000)
        let dayTwo = dayOne.addingTimeInterval(86_400)
        let dayThree = dayTwo.addingTimeInterval(86_400)

        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: dayOne, calendar: calendar)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: dayOne.addingTimeInterval(301), calendar: calendar)
        _ = RewardEngine.complete(activityID: "song-practice", snapshot: &snapshot, now: dayTwo, calendar: calendar)
        let result = RewardEngine.complete(activityID: "sight-reading", snapshot: &snapshot, now: dayThree, calendar: calendar)

        XCTAssertEqual(snapshot.state.streakLevel(for: "streak-3"), 3)
        XCTAssertTrue(result.events.contains(where: { $0.kind == .dailyStreak && $0.coins == 2 }))
        XCTAssertTrue(snapshot.state.rewardEvents.contains(where: { $0.kind == .combo }))
    }

    func testBreakPresetMaintainsFiveDayLevelAfterOneBreak() {
        var snapshot = GameSnapshot.seed
        snapshot.config.streaks = [
            StreakDefinition(
                id: "daily-practice",
                title: "Daily Practice",
                detail: "Practice daily.",
                activityIDs: ["warmup"],
                dailyMinimum: 1,
                bonusPreset: .breaks
            )
        ]

        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!

        for offset in 0..<5 {
            _ = RewardEngine.complete(
                activityID: "warmup",
                snapshot: &snapshot,
                now: start.addingTimeInterval(Double(offset * 86_400)),
                calendar: calendar
            )
        }
        let afterBreak = RewardEngine.complete(
            activityID: "warmup",
            snapshot: &snapshot,
            now: start.addingTimeInterval(6 * 86_400),
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state.streakLevel(for: "daily-practice"), 5)
        XCTAssertTrue(afterBreak.events.contains(where: { $0.kind == .dailyStreak && $0.coins == 3 }))
    }

    func testExceedingBreakAllowanceResetsStreakLevel() {
        var snapshot = GameSnapshot.seed
        snapshot.config.streaks = [
            StreakDefinition(
                id: "daily-practice",
                title: "Daily Practice",
                detail: "Practice daily.",
                activityIDs: ["warmup"],
                dailyMinimum: 1,
                bonusPreset: .breaks
            )
        ]

        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!

        for offset in 0..<5 {
            _ = RewardEngine.complete(
                activityID: "warmup",
                snapshot: &snapshot,
                now: start.addingTimeInterval(Double(offset * 86_400)),
                calendar: calendar
            )
        }
        let reset = RewardEngine.complete(
            activityID: "warmup",
            snapshot: &snapshot,
            now: start.addingTimeInterval(7 * 86_400),
            calendar: calendar
        )
        let restart = RewardEngine.complete(
            activityID: "warmup",
            snapshot: &snapshot,
            now: start.addingTimeInterval(8 * 86_400),
            calendar: calendar
        )

        XCTAssertFalse(reset.events.contains(where: { $0.kind == .dailyStreak }))
        XCTAssertEqual(snapshot.state.streakLevel(for: "daily-practice"), 2)
        XCTAssertTrue(restart.events.contains(where: { $0.kind == .dailyStreak && $0.coins == 1 }))
    }

    func testStreakIgnoresActivitiesOutsideConfiguredSet() {
        var snapshot = GameSnapshot.seed
        snapshot.config.streaks = [
            StreakDefinition(
                id: "warmup-only",
                title: "Warm-Up Only",
                detail: "Only warm-ups count.",
                activityIDs: ["warmup"],
                dailyMinimum: 1,
                bonusPreset: .noBreaks
            )
        ]

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let result = RewardEngine.complete(activityID: "song-practice", snapshot: &snapshot, now: now)

        XCTAssertFalse(result.events.contains(where: { $0.kind == .dailyStreak }))
        XCTAssertEqual(
            RewardEngine.streakLevel(for: snapshot.config.streaks[0], snapshot: snapshot, at: now),
            0
        )
    }

    func testDailyMinimumMustBeMetBeforeStreakUpdates() {
        var snapshot = GameSnapshot.seed
        snapshot.config.streaks = [
            StreakDefinition(
                id: "three-completions",
                title: "Three Completions",
                detail: "Complete three activities daily.",
                activityIDs: ["warmup", "song-practice", "sight-reading"],
                dailyMinimum: 3,
                bonusPreset: .noBreaks
            )
        ]

        let calendar = Calendar(identifier: .gregorian)
        let dayOne = Date(timeIntervalSince1970: 1_700_000_000)
        let dayTwo = dayOne.addingTimeInterval(86_400)

        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: dayOne, calendar: calendar)
        _ = RewardEngine.complete(activityID: "song-practice", snapshot: &snapshot, now: dayOne, calendar: calendar)
        _ = RewardEngine.complete(activityID: "sight-reading", snapshot: &snapshot, now: dayOne, calendar: calendar)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: dayTwo, calendar: calendar)
        _ = RewardEngine.complete(activityID: "song-practice", snapshot: &snapshot, now: dayTwo, calendar: calendar)
        let result = RewardEngine.complete(activityID: "sight-reading", snapshot: &snapshot, now: dayTwo, calendar: calendar)

        XCTAssertTrue(result.events.contains(where: { $0.kind == .dailyStreak && $0.coins == 1 }))
        XCTAssertEqual(snapshot.state.streakLevel(for: "three-completions"), 2)
    }

    func testCashOutUsesWatermarkInsteadOfReducingBalance() {
        var snapshot = GameSnapshot.seed
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        _ = RewardEngine.complete(activityID: "song-practice", snapshot: &snapshot, now: start)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: start.addingTimeInterval(301))

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
