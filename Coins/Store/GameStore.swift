import Foundation
import SwiftUI

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var snapshot: GameSnapshot
    @Published var latestResult: CompletionResult?
    @Published var celebrationToken = 0
    @Published var cashOutMessage: String?

    private let storageURL: URL
    private let speechCoordinator = SpeechCoordinator()

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("Coins", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        storageURL = directory.appendingPathComponent("snapshot.json")

        if let data = try? Data(contentsOf: storageURL),
           let loaded = try? JSONDecoder().decode(GameSnapshot.self, from: data) {
            snapshot = loaded
        } else {
            snapshot = .seed
        }
    }

    var activities: [Activity] {
        snapshot.config.activities
    }

    var achievements: [AchievementDefinition] {
        snapshot.config.achievements
    }

    var unlockedAchievements: [AchievementDefinition] {
        achievements.filter { snapshot.state.unlockedAchievementIDs.contains($0.id) }
    }

    func complete(_ activity: Activity) {
        var updated = snapshot
        let result = RewardEngine.complete(activityID: activity.id, snapshot: &updated)
        snapshot = updated
        latestResult = result
        cashOutMessage = nil
        persist()

        if !result.isDenied {
            celebrationToken += 1
        }
        if snapshot.config.speechEnabled {
            speechCoordinator.speak(result.speechText)
        }
    }

    func remainingLockout(for activity: Activity) -> Int {
        Int(ceil(RewardEngine.remainingLockout(for: activity, snapshot: snapshot)))
    }

    func progress(for activity: Activity) -> ActivityProgress {
        snapshot.state.activityProgress[activity.id] ?? ActivityProgress()
    }

    func cashOut() {
        var updated = snapshot
        guard let event = RewardEngine.cashOut(snapshot: &updated) else {
            cashOutMessage = "No new coins to cash out yet."
            return
        }
        snapshot = updated
        cashOutMessage = event.detail
        latestResult = CompletionResult(events: [event], deniedReason: nil, speechText: event.title)
        persist()
        if snapshot.config.speechEnabled {
            speechCoordinator.speak(event.detail)
        }
    }

    func adjustCoins(by delta: Int, reason: String) {
        var updated = snapshot
        guard let event = RewardEngine.adjustCoins(snapshot: &updated, delta: delta, reason: reason) else {
            return
        }
        snapshot = updated
        latestResult = CompletionResult(events: [event], deniedReason: nil, speechText: event.title)
        persist()
    }

    func apply(config: GameConfig) {
        snapshot.config = config
        persist()
    }

    func importSnapshot(_ newSnapshot: GameSnapshot) {
        snapshot = newSnapshot
        latestResult = nil
        cashOutMessage = "Imported JSON snapshot."
        persist()
    }

    func resetToSeedData() {
        snapshot = .seed
        latestResult = nil
        cashOutMessage = "Reset to seed data."
        persist()
    }

    func exportDocument() -> GameSnapshotDocument {
        GameSnapshotDocument(snapshot: snapshot)
    }

    func isMasterPasswordValid(_ password: String) -> Bool {
        snapshot.config.masterPassword == password
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
}

