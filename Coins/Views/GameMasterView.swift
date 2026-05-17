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
                        TextField("Title", text: $activity.title)
                        TextField("Detail", text: $activity.detail)
                        HStack {
                            Stepper("Reward \(activity.baseReward)", value: $activity.baseReward, in: 1...20)
                            Stepper("Lockout \(activity.lockoutSeconds)s", value: $activity.lockoutSeconds, in: 30...7200, step: 30)
                        }
                        Text("Symbol: \(activity.symbol)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
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
                    store.apply(config: draftConfig)
                }
                .fontWeight(.bold)
            }
        }
    }
}
