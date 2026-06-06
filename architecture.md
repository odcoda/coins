# Coins Architecture

Coins is a native SwiftUI iOS app built around one persisted aggregate, `GameSnapshot`. The app has no backend; local persistence and JSON import/export both encode the same snapshot model.

## Runtime Flow

`CoinsApp` creates one `@StateObject` `GameStore` and injects it as an environment object into `ContentView`.

`ContentView` owns the player shell: top bar, side drawer, page selection, coin-balance animation, reward overlay, and the one-second timer used to refresh lockout display state. Player activity taps call `GameStore.complete(_:)`.

`GameStore` is the main-actor boundary between SwiftUI and domain logic. It loads `snapshot.json` from Application Support at startup, falls back to `GameSnapshot.seed`, publishes snapshot changes, triggers speech, and persists after mutations. Store methods copy the current snapshot into a mutable local value, call `RewardEngine`, then publish the updated snapshot so SwiftUI observes state changes.

`RewardEngine` is the deterministic domain layer. It mutates an `inout GameSnapshot`, records activity and reward events, and returns a `CompletionResult` for UI presentation. It does not know about SwiftUI, files, speech, or navigation.

## Persisted Data Model

`GameSnapshot` has two top-level fields:

- `config: GameConfig`
- `state: GameState`

`GameConfig` is user-editable rule configuration:

- `theme`: currently only `.coins`.
- `speechEnabled`: enables speech for reward text.
- `masterPassword`: gates Game Master access.
- `activities`: configured real-world tasks.
- `dailyCompletionBonuses`: retained in the model but currently cleared by Game Master sanitization and not awarded by `RewardEngine`.
- `streaks`: configured daily streak definitions.
- `economy`: cash-out conversion settings.

`ActivityDefinition` controls one activity: stable `id`, display text, base reward, lockout seconds, SF Symbol name, repetition bonus preset, and daily maximum. A daily maximum of `0` means unlimited.

`DailyRepetitionBonusPreset` is activity-scoped same-day bonus logic. `.high3x` awards at 3/6/9/12 completions; `.medium5x` awards at 5/10/15/20 completions; `.none` disables repetition rewards.

`StreakDefinition` controls across-day streak rewards. It names qualifying activity IDs, a daily minimum count, a `StreakBonusPreset`, and an SF Symbol. `StreakBonusPreset` expands into fixed `StreakBonusLevel` values with day threshold, reward coins, and break allowance.

`EconomyConfig` stores `coinsPerCashOutAmount` and `cashOutCents`. Cash-out events do not reduce coin balance; they record a dollar amount and advance the derived cash-out watermark.

`GameState` is event-backed mutable state:

- `activityEvents`: completed or manually added activity history.
- `rewardEvents`: structured rewards, repetition bonuses, streak rewards, adjustments, and cash-outs.
- `streakProgress`: current manual or engine-updated level per streak.

`ActivityEvent` uses `ActivityEventOccurrence`, an either-or occurrence:

- `.timestamp(Date)` for real taps.
- `.manuallyAdded(day: Date)` for history-editor corrections.

Both occurrence kinds expose `createdAt` as an effective date so history and streak code can operate over one event stream.

`RewardEvent` is the reward ledger. `coins` is positive for earned rewards, negative only for manual adjustments, zero for cash-out, and is linked back to an activity event when applicable.

## Derived State

`GameState` derives balances and history from events:

- `coinBalance`: sum of all reward-event coins.
- `lifetimeCoins`: sum of positive reward-event coins.
- `cashedOutCoinsWatermark`: balance position at the latest cash-out, adjusted downward after rewinds.
- `pendingCashOutCoins`: current balance above the watermark.
- `cashedOutDollars`: sum of cash-out event dollar amounts.
- `rewardHistory`: reward events annotated with running balance.
- `ActivityStats`: total completions, today's completions, and latest completion for one activity.
- `ActivityHistoryDay`: per-day activity counts for the history editor.

The model intentionally avoids persisting cached balances, daily counts, or streak summaries.

## Reward Rules

`RewardEngine.complete(activityID:snapshot:now:calendar:)` applies rules in order:

1. Reject missing activity IDs.
2. Reject completions over the activity's daily maximum.
3. Reject taps inside the activity lockout window.
4. Append an `ActivityEvent`.
5. Append the structured base reward.
6. Append a repetition bonus if today's count hits the selected preset threshold.
7. Update all matching configured streaks and append any streak reward.

Streak rewards are evaluated only when today's qualifying count reaches the streak's `dailyMinimum`. Completed days are computed from `activityEvents`; levels are advanced through the preset thresholds when consecutive completed days qualify. Existing levels can persist through allowed breaks for presets that allow them.

`RewardEngine.cashOut` records a zero-coin cash-out event for the current pending coins. `RewardEngine.adjustCoins` records a manual adjustment but clamps rewinds so balance cannot go below zero.

## Game Master And Editing

`GameMasterView` is password-gated. Once unlocked, it separates:

- History editor.
- Streak state manual level controls.
- Rules editor.
- Balance adjustment sheet.
- JSON snapshot import/export.
- Password editor.

The rules editor edits a draft `GameConfig`. Saving sanitizes activity and streak references, clears `dailyCompletionBonuses`, applies the config through `GameStore.apply(config:)`, prunes orphaned streak progress, and persists.

`HistoryEditorView` shows a 30-day calendar-style grid ending at a selectable date. A day sheet edits counts from 0 to 50 per current activity. Saving rewrites that day's `activityEvents`, removing newest timestamped events first and adding manual events when counts increase. A separate save action can also apply the estimated base-plus-repetition balance delta through `GameStore.rewriteActivityHistory`.

`HistoryRewardEstimator` estimates history correction coins from activity definitions. It deliberately excludes streak effects.

## Files And Project Shape

Source lives under `Coins/`:

- `Models/GameModels.swift`: persisted schema, derived state, history rewrite helpers, and seed data.
- `Engine/RewardEngine.swift`: reward mutation rules.
- `Store/GameStore.swift`: published app state, persistence, speech dispatch, and store commands.
- `Views/ContentView.swift`: player shell and page routing.
- `Views/GameMasterView.swift`: password-gated configuration and admin flows.
- `Views/HistoryEditorView.swift`: activity-history repair UI.
- `Documents/GameSnapshotDocument.swift`: JSON import/export document wrapper.

Tests live under `CoinsTests/`, primarily as reward-engine and model-behavior tests.

`project.yml` is the XcodeGen source of truth for the Xcode project. `Coins.xcodeproj/project.pbxproj` is generated project output, although local signing settings may diverge when configured through Xcode.
