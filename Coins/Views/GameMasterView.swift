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
    @State private var isShowingSavedConfirmation = false
    @State private var saveConfirmationNonce = 0
    @State private var isShowingHistoryEditor = false
    @State private var isShowingRulesEditor = false
    @State private var isShowingPasswordEditor = false
    @State private var isShowingBalanceEditor = false
    @State private var pendingBalanceAdjustment = 0

    private let rewardOptions = Array(0...50)
    private let lockoutOptions = Array(stride(from: 5, through: 60, by: 5)) + Array(stride(from: 120, through: 600, by: 60))
    private let dailyMinimumOptions = [1, 3, 5, 12, 20]
    private let dailyMaximumOptions = [0, 1, 5, 12, 20]
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
        IconOption(title: "Target", symbol: "target"),
        IconOption(title: "Hand", symbol: "hand.raised.fill"),
        IconOption(title: "Finger", symbol: "hand.point.up.fill"),
        IconOption(title: "Piano", symbol: "pianokeys"),
        IconOption(title: "Notes", symbol: "music.quarternote.3")
    ]

    private var rateSummary: String {
        let coins = draftConfig.economy.coinsPerCashOutAmount
        let coinLabel = coins == 1 ? "coin" : "coins"
        return String(format: "%d %@ for $%.2f", coins, coinLabel, draftConfig.economy.cashOutDollars)
    }

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
        .fullScreenCover(isPresented: $isShowingHistoryEditor) {
            HistoryEditorView()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $isShowingRulesEditor) {
            rulesEditor
        }
        .fullScreenCover(isPresented: $isShowingPasswordEditor) {
            PasswordEditorView()
                .environmentObject(store)
        }
        .sheet(isPresented: $isShowingBalanceEditor) {
            BalanceEditorSheet(
                currentBalance: store.snapshot.state.coinBalance,
                adjustment: $pendingBalanceAdjustment,
                reason: $adjustmentReason
            ) {
                store.adjustCoins(by: pendingBalanceAdjustment, reason: adjustmentReason)
                pendingBalanceAdjustment = 0
                isShowingBalanceEditor = false
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
            Section("History") {
                Button {
                    isShowingHistoryEditor = true
                } label: {
                    Label("Open History Editor", systemImage: "calendar.badge.clock")
                }
            }

            Section("Streak State") {
                if draftConfig.streaks.isEmpty {
                    Text("No streaks configured.")
                        .foregroundStyle(.secondary)
                }

                ForEach(draftConfig.streaks) { streak in
                    Picker(streak.title.isEmpty ? "Streak level" : streak.title, selection: streakLevelBinding(for: streak.id, preset: streak.bonusPreset)) {
                        Text("None").tag(0)
                        ForEach(streak.bonusPreset.levels, id: \.days) { level in
                            Text("\(level.days) days").tag(level.days)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Section("Configuration") {
                Button {
                    isShowingRulesEditor = true
                } label: {
                    Label("Configure Rules", systemImage: "slider.horizontal.3")
                }
            }

            Section("Balance") {
                Button {
                    pendingBalanceAdjustment = 0
                    isShowingBalanceEditor = true
                } label: {
                    Label("Change Balance", systemImage: "plus.forwardslash.minus")
                }
            }

            Section("Sync") {
                Button("Export JSON Snapshot") {
                    exportDocument = store.exportDocument()
                    isExporting = true
                }
                Button("Import JSON Snapshot") {
                    isImporting = true
                }
            }

            Section("Password") {
                Button {
                    isShowingPasswordEditor = true
                } label: {
                    Label("Change Password", systemImage: "key.fill")
                }
            }
        }
    }

    private var rulesEditor: some View {
        NavigationStack {
            Form {
                rulesSections
            }
            .navigationTitle("Configure Rules")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isShowingRulesEditor = false
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveBar
            }
        }
    }

    private var rulesSections: some View {
        Group {
            Section("Basics") {
                Toggle("Read reward text aloud", isOn: $draftConfig.speechEnabled)
                Picker("Theme", selection: $draftConfig.theme) {
                    ForEach(ThemeID.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                HStack {
                    Text("Cash-out rate")
                    Spacer()
                    Text(rateSummary)
                        .foregroundStyle(.secondary)
                }
                Stepper(value: $draftConfig.economy.coinsPerCashOutAmount, in: 1...1_000, step: 1) {
                    Text("\(draftConfig.economy.coinsPerCashOutAmount) \(draftConfig.economy.coinsPerCashOutAmount == 1 ? "coin" : "coins")")
                }
                Stepper(value: $draftConfig.economy.cashOutCents, in: 1...10_000, step: 1) {
                    Text(String(format: "$%.2f", draftConfig.economy.cashOutDollars))
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

                        Picker("Repetition Bonus", selection: $activity.repetitionBonusPreset) {
                            ForEach(DailyRepetitionBonusPreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Daily Maximum", selection: $activity.dailyMaximum) {
                            ForEach(dailyMaximumOptions(for: activity.dailyMaximum), id: \.self) { maximum in
                                Text(dailyMaximumLabel(maximum)).tag(maximum)
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

                        Picker("Daily minimum", selection: $streak.dailyMinimum) {
                            ForEach(dailyMinimumOptions, id: \.self) { minimum in
                                Text("\(minimum) \(minimum == 1 ? "activity" : "activities")").tag(minimum)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Bonus preset", selection: $streak.bonusPreset) {
                            ForEach(StreakBonusPreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
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
        }
    }

    private var saveBar: some View {
        VStack(spacing: 8) {
            if isShowingSavedConfirmation {
                Label("Configuration saved", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button {
                saveConfiguration()
            } label: {
                Label(
                    isShowingSavedConfirmation ? "Saved" : "Save Configuration",
                    systemImage: isShowingSavedConfirmation ? "checkmark.circle.fill" : "square.and.arrow.down.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .fontWeight(.bold)
            .buttonStyle(.borderedProminent)
            .tint(isShowingSavedConfirmation ? .green : .orange)
            .scaleEffect(isShowingSavedConfirmation ? 1.03 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.62), value: isShowingSavedConfirmation)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }

    private func addActivity() {
        draftConfig.activities.append(
            ActivityDefinition(
                id: "activity-\(UUID().uuidString)",
                title: "New Activity",
                detail: "Describe the real-world activity.",
                baseReward: 1,
                lockoutSeconds: 30,
                symbol: "checkmark.circle.fill",
                repetitionBonusPreset: .medium5x,
                dailyMaximum: 20
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
                detail: "Complete enough qualifying activities daily.",
                activityIDs: draftConfig.activities.map(\.id),
                dailyMinimum: 1,
                bonusPreset: .noBreaks,
                symbol: "flame.fill"
            )
        )
    }

    private func removeStreak(id: String) {
        draftConfig.streaks.removeAll { $0.id == id }
    }

    private func saveConfiguration() {
        store.apply(config: sanitizedConfig())
        saveConfirmationNonce += 1
        let currentNonce = saveConfirmationNonce
        withAnimation(.spring(response: 0.24, dampingFraction: 0.66)) {
            isShowingSavedConfirmation = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                guard saveConfirmationNonce == currentNonce else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    isShowingSavedConfirmation = false
                }
            }
        }
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
            if !dailyMinimumOptions.contains(config.streaks[index].dailyMinimum) {
                config.streaks[index].dailyMinimum = 1
            }
            config.streaks[index].activityIDs = config.streaks[index].activityIDs.filter { validActivityIDs.contains($0) }
            if config.streaks[index].symbol.isEmpty {
                config.streaks[index].symbol = "flame.fill"
            }
        }
        config.dailyCompletionBonuses = []
        for index in config.activities.indices {
            if config.activities[index].symbol.isEmpty {
                config.activities[index].symbol = "checkmark.circle.fill"
            }
            config.activities[index].dailyMaximum = nearestDailyMaximum(to: config.activities[index].dailyMaximum)
        }
        return config
    }

    private func streakLevelBinding(for streakID: String, preset: StreakBonusPreset) -> Binding<Int> {
        Binding {
            let currentLevel = store.snapshot.state.streakLevel(for: streakID)
            let allowedLevels = Set(preset.levels.map(\.days))
            return allowedLevels.contains(currentLevel) ? currentLevel : 0
        } set: { level in
            store.adjustStreakLevel(streakID: streakID, levelDays: level)
        }
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

    private func dailyMaximumOptions(for currentValue: Int) -> [Int] {
        Array(Set(dailyMaximumOptions + [currentValue])).sorted()
    }

    private func nearestDailyMaximum(to value: Int) -> Int {
        guard value > 0 else {
            return 0
        }
        return dailyMaximumOptions.min { lhs, rhs in
            abs(lhs - value) < abs(rhs - value)
        } ?? 5
    }

    private func dailyMaximumLabel(_ maximum: Int) -> String {
        return maximum == 0 ? "No limit" : "\(maximum) per day"
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

private struct PasswordEditorView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?

    private var canSave: Bool {
        !password.isEmpty && password == confirmation
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("New Password") {
                    SecureField("Password", text: $password)
                    SecureField("Enter password again", text: $confirmation)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        savePassword()
                    } label: {
                        Label("Change Password", systemImage: "key.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                }
            }
            .navigationTitle("Change Password")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func savePassword() {
        guard !password.isEmpty else {
            errorMessage = "Enter a password."
            return
        }
        guard password == confirmation else {
            errorMessage = "Passwords do not match."
            return
        }

        var config = store.snapshot.config
        config.masterPassword = password
        store.apply(config: config)
        dismiss()
    }
}

private struct BalanceEditorSheet: View {
    let currentBalance: Int
    @Binding var adjustment: Int
    @Binding var reason: String
    let onSave: () -> Void

    private var adjustedBalance: Int {
        currentBalance + adjustment
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                TextField("Adjustment reason", text: $reason)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 12) {
                    adjustmentButton("-10", delta: -10)
                    adjustmentButton("-1", delta: -1)

                    VStack(spacing: 6) {
                        Text("\(adjustedBalance)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(diffText)
                            .font(.headline)
                            .foregroundStyle(diffColor)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)

                    adjustmentButton("+1", delta: 1)
                    adjustmentButton("+10", delta: 10)
                }

                Button {
                    onSave()
                } label: {
                    Label("Save Changes", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .fontWeight(.bold)
                .buttonStyle(.borderedProminent)
                .disabled(adjustment == 0)
            }
            .padding(20)
            .navigationTitle("Change Balance")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var diffText: String {
        if adjustment > 0 {
            return "+\(adjustment)"
        }
        return "\(adjustment)"
    }

    private var diffColor: Color {
        if adjustment > 0 {
            return .green
        }
        if adjustment < 0 {
            return .red
        }
        return .secondary
    }

    private func adjustmentButton(_ title: String, delta: Int) -> some View {
        Button {
            adjustment += delta
        } label: {
            Text(title)
                .font(.headline.weight(.bold))
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.bordered)
    }
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
