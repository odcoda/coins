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
    @State private var iconSelection: IconSelection?

    private let rewardOptions = Array(0...50)
    private let lockoutOptions = Array(stride(from: 5, through: 60, by: 5)) + Array(stride(from: 120, through: 600, by: 60))
    private let iconOptions = [
        IconOption(title: "Leaf", symbol: "leaf.fill"),
        IconOption(title: "Music", symbol: "music.note"),
        IconOption(title: "Eye", symbol: "eye.fill"),
        IconOption(title: "Check", symbol: "checkmark.circle.fill"),
        IconOption(title: "Flame", symbol: "flame.fill"),
        IconOption(title: "Sparkles", symbol: "sparkles"),
        IconOption(title: "Sun", symbol: "sun.max.fill"),
        IconOption(title: "Star", symbol: "star.fill"),
        IconOption(title: "Book", symbol: "book.fill"),
        IconOption(title: "Pencil", symbol: "pencil"),
        IconOption(title: "Trophy", symbol: "trophy.fill"),
        IconOption(title: "Target", symbol: "target")
    ]

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
        .sheet(item: $iconSelection) { selection in
            IconPickerSheet(
                title: selection.title,
                selectedSymbol: currentSymbol(for: selection),
                options: iconOptions
            ) { symbol in
                setIcon(symbol, for: selection)
                iconSelection = nil
            }
            .presentationDetents([.medium])
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
                            iconButton(
                                symbol: activity.symbol,
                                accessibilityLabel: "Change Activity Icon"
                            ) {
                                iconSelection = IconSelection(
                                    kind: .activity,
                                    id: activity.id,
                                    title: activity.title.isEmpty ? "Activity Icon" : activity.title
                                )
                            }
                            Text(activity.title.isEmpty ? "Activity" : activity.title)
                                .font(.headline)
                            Spacer()
                            Button(role: .destructive) {
                                removeActivity(id: activity.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                            .disabled(draftConfig.activities.count <= 1)
                            .accessibilityLabel("Delete Activity")
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
                            iconButton(
                                symbol: streak.symbol,
                                accessibilityLabel: "Change Streak Icon"
                            ) {
                                iconSelection = IconSelection(
                                    kind: .streak,
                                    id: streak.id,
                                    title: streak.title.isEmpty ? "Streak Icon" : streak.title
                                )
                            }
                            Text(streak.title.isEmpty ? "Streak" : streak.title)
                                .font(.headline)
                            Spacer()
                            Button(role: .destructive) {
                                removeStreak(id: streak.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete Streak")
                        }

                        TextField("Streak text", text: $streak.title)
                        TextField("Reward detail", text: $streak.detail, axis: .vertical)
                            .lineLimit(2...4)

                        Picker("Frequency", selection: $streak.frequency) {
                            ForEach(StreakFrequency.allCases) { frequency in
                                Text(frequency.displayName).tag(frequency)
                            }
                        }
                        .pickerStyle(.menu)

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
                extraRewardCoins: 0,
                symbol: "flame.fill"
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
            if config.streaks[index].symbol.isEmpty {
                config.streaks[index].symbol = "flame.fill"
            }
        }
        for index in config.activities.indices where config.activities[index].symbol.isEmpty {
            config.activities[index].symbol = "checkmark.circle.fill"
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

    private func iconButton(symbol: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(.orange)
                .frame(width: 34, height: 34)
                .background(Color.orange.opacity(0.14), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func currentSymbol(for selection: IconSelection) -> String {
        switch selection.kind {
        case .activity:
            return draftConfig.activities.first(where: { $0.id == selection.id })?.symbol ?? "checkmark.circle.fill"
        case .streak:
            return draftConfig.streaks.first(where: { $0.id == selection.id })?.symbol ?? "flame.fill"
        }
    }

    private func setIcon(_ symbol: String, for selection: IconSelection) {
        switch selection.kind {
        case .activity:
            guard let index = draftConfig.activities.firstIndex(where: { $0.id == selection.id }) else { return }
            draftConfig.activities[index].symbol = symbol
        case .streak:
            guard let index = draftConfig.streaks.firstIndex(where: { $0.id == selection.id }) else { return }
            draftConfig.streaks[index].symbol = symbol
        }
    }
}

private enum IconSelectionKind {
    case activity
    case streak
}

private struct IconSelection: Identifiable {
    let kind: IconSelectionKind
    let id: String
    let title: String
}

private struct IconOption: Identifiable {
    let title: String
    let symbol: String

    var id: String { symbol }
}

private struct IconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let selectedSymbol: String
    let options: [IconOption]
    let onSelect: (String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 12)], spacing: 12) {
                    ForEach(options) { option in
                        Button {
                            onSelect(option.symbol)
                            dismiss()
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: option.symbol)
                                    .font(.title2.weight(.bold))
                                    .frame(width: 42, height: 42)
                                Text(option.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(option.symbol == selectedSymbol ? .white : .primary)
                            .frame(maxWidth: .infinity, minHeight: 74)
                            .background(
                                option.symbol == selectedSymbol ? Color.orange : Color.orange.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
