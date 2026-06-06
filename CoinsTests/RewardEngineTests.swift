import XCTest
@testable import Coins

final class RewardEngineTests: XCTestCase {
    func testLockoutBlocksRapidTaps() {
        var snapshot = GameSnapshot.seed
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        snapshot.config.activities[0].lockoutSeconds = 300

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

        XCTAssertEqual(snapshot.state.streakLevel(for: "streak-3"), 3)
        XCTAssertTrue(result.events.contains(where: { $0.kind == .dailyStreak && $0.coins == 2 }))
        XCTAssertTrue(snapshot.state.rewardEvents.contains(where: { $0.kind == .combo }))
    }

    func testMediumRepetitionPresetAwardsAtConfiguredThresholds() {
        var snapshot = GameSnapshot.seed
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        snapshot.config.activities[1].lockoutSeconds = 0
        snapshot.config.activities[1].repetitionBonusPreset = .medium5x

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

    func testDailyMaximumZeroAllowsUnlimitedCompletions() {
        var snapshot = GameSnapshot.seed
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        snapshot.config.activities[0].lockoutSeconds = 0
        snapshot.config.activities[0].dailyMaximum = 0

        var results: [CompletionResult] = []
        for offset in 0..<13 {
            results.append(
                RewardEngine.complete(
                    activityID: "warmup",
                    snapshot: &snapshot,
                    now: start.addingTimeInterval(Double(offset)),
                    calendar: calendar
                )
            )
        }

        XCTAssertFalse(results.contains(where: \.isDenied))
        XCTAssertEqual(snapshot.state.activityEvents.count, 13)
        XCTAssertTrue(results[11].events.contains(where: { $0.kind == .combo && $0.coins == 5 }))
        XCTAssertFalse(results[12].events.contains(where: { $0.kind == .combo }))
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
        XCTAssertEqual(snapshot.state.coinBalance, 3)
        XCTAssertNil(secondCashOut)
        XCTAssertEqual(snapshot.state.cashedOutCoinsWatermark, 3)
        XCTAssertEqual(snapshot.config.economy.coinsPerCashOutAmount, 5)
        XCTAssertEqual(snapshot.config.economy.cashOutCents, 1)
        XCTAssertEqual(snapshot.state.cashedOutDollars, 0.006, accuracy: 0.0001)
    }

    func testCashOutUsesAdjustableCoinsForCentsRate() {
        var snapshot = GameSnapshot.seed
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        snapshot.config.economy = EconomyConfig(coinsPerCashOutAmount: 3, cashOutCents: 25)

        _ = RewardEngine.complete(activityID: "song-practice", snapshot: &snapshot, now: start)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: start.addingTimeInterval(301))

        let cashOut = RewardEngine.cashOut(snapshot: &snapshot, now: start.addingTimeInterval(600))

        XCTAssertNotNil(cashOut)
        XCTAssertEqual(snapshot.state.coinBalance, 3)
        XCTAssertEqual(snapshot.state.cashedOutDollars, 0.25, accuracy: 0.0001)
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

    func testHistoryRewriteCutsLaterTimestampsFirstAndAddsManualEvents() {
        var snapshot = GameSnapshot.seed
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.date(from: DateComponents(year: 2024, month: 1, day: 8))!
        snapshot.config.activities[0].lockoutSeconds = 0

        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: day.addingTimeInterval(60), calendar: calendar)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: day.addingTimeInterval(120), calendar: calendar)
        _ = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: day.addingTimeInterval(180), calendar: calendar)

        snapshot.state.rewriteActivityHistory(
            on: day,
            countsByActivityID: ["warmup": 1],
            activities: snapshot.config.activities,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.state.activityCounts(on: day, calendar: calendar)["warmup"], 1)
        XCTAssertEqual(snapshot.state.activityEvents.first?.createdAt, day.addingTimeInterval(60))

        snapshot.state.rewriteActivityHistory(
            on: day,
            countsByActivityID: ["warmup": 3],
            activities: snapshot.config.activities,
            calendar: calendar
        )

        let warmupEvents = snapshot.state.activityEvents.filter { $0.activityID == "warmup" }
        XCTAssertEqual(warmupEvents.count, 3)
        XCTAssertEqual(warmupEvents.filter(\.isManuallyAdded).count, 2)
        XCTAssertEqual(warmupEvents.compactMap(\.timestamp), [day.addingTimeInterval(60)])
    }

    func testHistoryRewardEstimatorUsesCurrentBaseRewardsAndRepetitionBonuses() {
        var snapshot = GameSnapshot.seed
        snapshot.config.activities[0].baseReward = 2
        snapshot.config.activities[0].repetitionBonusPreset = .high3x
        snapshot.config.activities[1].baseReward = 4
        snapshot.config.activities[1].repetitionBonusPreset = .medium5x

        let coins = HistoryRewardEstimator.coins(
            for: [
                "warmup": 6,
                "song-practice": 5
            ],
            activities: snapshot.config.activities
        )

        XCTAssertEqual(coins, 36)
    }

    func testHistoryRewardEstimatorDeltaIgnoresStreakRewards() {
        var snapshot = GameSnapshot.seed
        snapshot.config.activities[0].baseReward = 1
        snapshot.config.activities[0].repetitionBonusPreset = .high3x
        snapshot.config.streaks = [
            StreakDefinition(
                id: "daily-practice",
                title: "Daily Practice",
                detail: "Practice daily.",
                activityIDs: ["warmup"],
                dailyMinimum: 1,
                bonusPreset: .noBreaks
            )
        ]

        let delta = HistoryRewardEstimator.delta(
            from: ["warmup": 2],
            to: ["warmup": 3],
            activities: snapshot.config.activities
        )

        XCTAssertEqual(delta, 2)
    }

    func testManuallyAddedHistoryCountsTowardFutureStreakLogic() {
        var snapshot = GameSnapshot.seed
        snapshot.config.streaks = [
            StreakDefinition(
                id: "daily-practice",
                title: "Daily Practice",
                detail: "Practice daily.",
                activityIDs: ["warmup"],
                dailyMinimum: 1,
                bonusPreset: .noBreaks
            )
        ]
        let calendar = Calendar(identifier: .gregorian)
        let dayOne = calendar.date(from: DateComponents(year: 2024, month: 1, day: 8))!
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: dayOne)!
        let dayThree = calendar.date(byAdding: .day, value: 2, to: dayOne)!

        snapshot.state.rewriteActivityHistory(
            on: dayOne,
            countsByActivityID: ["warmup": 1],
            activities: snapshot.config.activities,
            calendar: calendar
        )
        snapshot.state.rewriteActivityHistory(
            on: dayTwo,
            countsByActivityID: ["warmup": 1],
            activities: snapshot.config.activities,
            calendar: calendar
        )
        let result = RewardEngine.complete(activityID: "warmup", snapshot: &snapshot, now: dayThree, calendar: calendar)

        XCTAssertEqual(snapshot.state.streakLevel(for: "daily-practice"), 3)
        XCTAssertTrue(result.events.contains(where: { $0.kind == .dailyStreak && $0.coins == 2 }))
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
