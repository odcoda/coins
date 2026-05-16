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

    func testComboAndDailyStreakRewardsStack() {
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
