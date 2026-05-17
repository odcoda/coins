import SwiftUI

struct GameMasterView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    var showsCloseButton = true

    @State private var password = ""
    @State private var isUnlocked = false
    @State private var draftConfig = GameSnapshot.seed.config
    @State private var adjustmentReason = "Manual correction"
    @State private var exportDocument = GameSnapshotDocument(snapshot: .seed)
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var importError: String?

    private let rewardOptions = Array(0...50)
    private let lockoutOptions = Array(stride(from: 5, through: 60, by: 5)) + Array(stride(from: 120, through: 600, by: 60))

    var body: some View {
        if showsCloseButton {
            NavigationStack {
                content
                    .navigationTitle("Game Master")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") {
                                dismiss()
                            }
                        }
                    }
            }
        } else {
            content
        }
    }

    private var content: some View {
        Group {
            if isUnlocked {
                editor
            } else {
                lockedView
            }
        }
        .onAppear {
            draftConfig = store.snapshot.config
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "coins-snapshot"
        ) { _ in }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json]
        ) { result in
            do {
                let url = try result.get()
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let snapshot = try decoder.decode(GameSnapshot.self, from: data)
                store.importSnapshot(snapshot)
                draftConfig = snapshot.config
            } catch {
                importError = error.localizedDescription
            }
        }
        .alert("Import Failed", isPresented: Binding(get: { importError != nil }, set: { _ in importError = nil })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    private var lockedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 42))
                .foregroundStyle(.orange)

            Text("Enter the game-master password to edit rewards, balance, and sync.")
                .font(.headline)
                .multilineTextAlignment(.center)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Button("Unlock") {
                isUnlocked = store.isMasterPasswordValid(password)
            }
            .buttonStyle(.borderedProminent)

            if !password.isEmpty && !isUnlocked {
                Text("The seed password is 1234 until you change it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
    }

    private var editor: some View {
        Form {
            Section("Basics") {
                Toggle("Read reward text aloud", isOn: $draftConfig.speechEnabled)
                Picker("Theme", selection: $draftConfig.theme) {
                    ForEach(ThemeID.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                HStack {
                    Text("Coins per dollar")
                    Spacer()
                    Stepper(value: $draftConfig.economy.coinsPerDollar, in: 1...200, step: 1) {
                        Text(String(format: "%.0f", draftConfig.economy.coinsPerDollar))
                    }
                    .fixedSize()
                }
            }

            Section("Activities") {
                ForEach($draftConfig.activities) { $activity in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(activity.title.isEmpty ? "Activity" : activity.title, systemImage: activity.symbol)
                                .font(.headline)
                            Spacer()
                            Button(role: .destructive) {
                                removeActivity(id: activity.id)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .disabled(draftConfig.activities.count <= 1)
                        }

                        TextField("Title", text: $activity.title)
                        TextField("Detail", text: $activity.detail)

                        Picker("Reward", selection: $activity.baseReward) {
                            ForEach(rewardOptions, id: \.self) { reward in
                                Text("\(reward) \(reward == 1 ? "coin" : "coins")").tag(reward)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Lockout", selection: $activity.lockoutSeconds) {
                            ForEach(lockoutOptions(for: activity.lockoutSeconds), id: \.self) { seconds in
                                Text(lockoutLabel(seconds)).tag(seconds)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.vertical, 6)
                }

                Button {
                    addActivity()
                } label: {
                    Label("Add Activity", systemImage: "plus.circle.fill")
                }
            }

            Section("Streaks") {
                if draftConfig.streaks.isEmpty {
                    Text("No streaks configured.")
                        .foregroundStyle(.secondary)
                }

                ForEach($draftConfig.streaks) { $streak in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(streak.title.isEmpty ? "Streak" : streak.title, systemImage: "flame.fill")
                                .font(.headline)
                            Spacer()
                            Button(role: .destructive) {
                                removeStreak(id: streak.id)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }

                        TextField("Streak text", text: $streak.title)
                        TextField("Reward detail", text: $streak.detail, axis: .vertical)
                            .lineLimit(2...4)

                        Picker("Frequency", selection: $streak.frequency) {
                            ForEach(StreakFrequency.allCases) { frequency in
                                Text(frequency.displayName).tag(frequency)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("Reward", selection: $streak.rewardCoins) {
                            ForEach(rewardOptions, id: \.self) { reward in
                                Text("\(reward) \(reward == 1 ? "coin" : "coins")").tag(reward)
                            }
                        }
                        .pickerStyle(.menu)

                        Stepper(
                            "Minimum length \(streak.minimumLength)",
                            value: $streak.minimumLength,
                            in: 1...60
                        )

                        Picker("Extra per period", selection: $streak.extraRewardCoins) {
                            ForEach(rewardOptions, id: \.self) { reward in
                                Text(reward == 0 ? "None" : "+\(reward)").tag(reward)
                            }
                        }
                        .pickerStyle(.menu)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Activities that count")
                                .font(.subheadline.weight(.semibold))
                            ForEach(draftConfig.activities) { activity in
                                Toggle(
                                    activity.title.isEmpty ? "Untitled activity" : activity.title,
                                    isOn: activityIncludedBinding(for: $streak, activityID: activity.id)
                                )
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

                Button {
                    addStreak()
                } label: {
                    Label("Add Streak", systemImage: "plus.circle.fill")
                }
            }

            Section("Treasure Chest") {
                Toggle("Enable surprise rewards", isOn: $draftConfig.treasureChest.isEnabled)
                Stepper("Min daily streak \(draftConfig.treasureChest.minDailyStreak)", value: $draftConfig.treasureChest.minDailyStreak, in: 1...30)
                Stepper("Min daily completions \(draftConfig.treasureChest.minDailyCompletions)", value: $draftConfig.treasureChest.minDailyCompletions, in: 1...20)
                HStack {
                    Text("Drop chance")
                    Slider(value: $draftConfig.treasureChest.chance, in: 0.05...1.0, step: 0.05)
                    Text("\(Int(draftConfig.treasureChest.chance * 100))%")
                        .monospacedDigit()
                }
                Stepper("Chest min \(draftConfig.treasureChest.minCoins)", value: $draftConfig.treasureChest.minCoins, in: 1...20)
                Stepper("Chest max \(draftConfig.treasureChest.maxCoins)", value: $draftConfig.treasureChest.maxCoins, in: draftConfig.treasureChest.minCoins...30)
            }

            Section("Balance Controls") {
                Button("+1 Coin") {
                    store.adjustCoins(by: 1, reason: adjustmentReason)
                }
                Button("-1 Coin") {
                    store.adjustCoins(by: -1, reason: adjustmentReason)
                }
                Button("-5 Coins") {
                    store.adjustCoins(by: -5, reason: adjustmentReason)
                }
                TextField("Adjustment reason", text: $adjustmentReason)
            }

            Section("Sync") {
                Button("Export JSON Snapshot") {
                    exportDocument = store.exportDocument()
                    isExporting = true
                }
                Button("Import JSON Snapshot") {
                    isImporting = true
                }
                Button("Reset to Seed Data", role: .destructive) {
                    store.resetToSeedData()
                    draftConfig = store.snapshot.config
                }
            }

            Section("Password") {
                SecureField("Game-master password", text: $draftConfig.masterPassword)
            }

            Section {
                Button("Save Configuration") {
                    store.apply(config: sanitizedConfig())
                }
                .fontWeight(.bold)
            }
        }
    }

    private func addActivity() {
        draftConfig.activities.append(
            Activity(
                id: "activity-\(UUID().uuidString)",
                title: "New Activity",
                detail: "Describe the real-world activity.",
                baseReward: 1,
                lockoutSeconds: 60,
                symbol: "checkmark.circle.fill"
            )
        )
    }

    private func removeActivity(id: String) {
        guard draftConfig.activities.count > 1 else { return }
        draftConfig.activities.removeAll { $0.id == id }
        for index in draftConfig.streaks.indices {
            draftConfig.streaks[index].activityIDs.removeAll { $0 == id }
        }
    }

    private func addStreak() {
        draftConfig.streaks.append(
            StreakDefinition(
                id: "streak-\(UUID().uuidString)",
                title: "New Streak",
                detail: "Complete a qualifying activity on schedule.",
                activityIDs: draftConfig.activities.map(\.id),
                frequency: .daily,
                minimumLength: 3,
                rewardCoins: 3,
                extraRewardCoins: 0
            )
        )
    }

    private func removeStreak(id: String) {
        draftConfig.streaks.removeAll { $0.id == id }
    }

    private func activityIncludedBinding(for streak: Binding<StreakDefinition>, activityID: String) -> Binding<Bool> {
        Binding {
            streak.wrappedValue.activityIDs.contains(activityID)
        } set: { isIncluded in
            var activityIDs = streak.wrappedValue.activityIDs
            if isIncluded {
                if !activityIDs.contains(activityID) {
                    activityIDs.append(activityID)
                }
            } else {
                activityIDs.removeAll { $0 == activityID }
            }
            streak.wrappedValue.activityIDs = activityIDs
        }
    }

    private func sanitizedConfig() -> GameConfig {
        var config = draftConfig
        let validActivityIDs = Set(config.activities.map(\.id))
        for index in config.streaks.indices {
            config.streaks[index].minimumLength = max(config.streaks[index].minimumLength, 1)
            config.streaks[index].rewardCoins = min(max(config.streaks[index].rewardCoins, 0), 50)
            config.streaks[index].extraRewardCoins = min(max(config.streaks[index].extraRewardCoins, 0), 50)
            config.streaks[index].activityIDs = config.streaks[index].activityIDs.filter { validActivityIDs.contains($0) }
        }
        return config
    }

    private func lockoutOptions(for currentValue: Int) -> [Int] {
        Array(Set(lockoutOptions + [currentValue])).sorted()
    }

    private func lockoutLabel(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) seconds"
        }
        if seconds == 60 {
            return "1 minute"
        }
        return "\(seconds / 60) minutes"
    }
}
