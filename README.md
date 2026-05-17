# Coins

Native iOS reward game for turning real-world practice into a coin-collecting loop.

Coins is built for tasks that need repeated deliberate effort, such as instrument
practice, studying, chores, or project work. The app does not verify the real
world work; it gives a configurable reward loop around a trusted completion tap.

## Current MVP

- SwiftUI iPhone/iPad app
- Configurable activities with picker-based rewards and lockouts
- Same-day combo bonuses and configurable daily/weekly/monthly streak bonuses
- Surprise treasure chests gated by streak/completion thresholds
- Achievement unlocks
- Always-visible coin balance with a reward fly-up animation
- Separate piggy bank page with streak and cash-out tracking
- Separate tracking page with achievements, recent rewards, and reward-history charts
- Password-gated game-master panel
- JSON export/import of full app state

## App Flow

The player shell has a persistent top bar with the current coin balance. Swipe
right from the left edge, or use the top-left sidebar button, to reveal the
hidden navigation drawer for Main, Piggy Bank, Tracking, and Game Master.

The Main page is the activity loop. Tapping an activity awards its structured
coin reward, then checks for same-day combo bonuses, daily streak bonuses,
surprise treasure chests, and newly unlocked achievements. Positive rewards
briefly show a centered coin message, then collapse toward the top balance while
the balance ticks upward.

Activity cards lock after a completion. The countdown refreshes every second on
the main screen, and a locked activity cannot be tapped again until the timer
expires.

The Piggy Bank page shows the larger balance context, daily streak, cashed-out
dollars, pending cash-out value, and the cash-out control.

The Tracking page shows today/lifetime/unlocked stats, unlocked achievements,
recent reward ledger entries, a rewards-by-day bar chart, and a cumulative coins
line chart. These charts are built from the reward ledger, which records the
timestamp, coin delta, balance, and reward kind for each event.

Game Master is opened from the drawer. The seeded password is `1234`. Game
Master currently supports speech mode, adding/removing/editing activities,
picker-based activity reward/lockout edits, configurable activity-scoped
streaks, treasure chest tuning, balance adjustments, JSON import/export, seed
reset, and changing the game-master password.

Cash Out does not remove coins from the piggy bank. It records how many new coins
have been converted to earned dollars since the last cash-out, using the
configured coins-per-dollar ratio.

## Reward Model

Reward behavior lives in [RewardEngine.swift](Coins/Engine/RewardEngine.swift).
The engine is intentionally deterministic when tests pass explicit dates and
random rolls.

- `Activity` gives the known structured reward and has its own lockout.
- `ComboMilestone` triggers from total completions during the current day.
- `StreakDefinition` triggers once per configured period for its chosen
  activities, with optional extra reward growth after the minimum streak length.
- `TreasureChestConfig` gates random bonuses behind streak and daily-completion thresholds.
- `AchievementDefinition` unlocks one-time bonuses from configured metrics.
- `LedgerEntry` records all rewards, adjustments, and cash-out events.

## Persistence And Sync

The app stores a `GameSnapshot`, which contains both `GameConfig` and
`GameState`, as JSON in app support storage. Game Master's export/import actions
use the same snapshot format, so a complete local game can be backed up,
restored, or moved to another device manually.

Longer term, this snapshot shape is the natural boundary for server sync: send
operations or snapshots to a backend, then reconcile into `GameSnapshot`.

## Repo Layout

- `Coins/App`: app entry point.
- `Coins/Models`: codable config, state, activity, reward, and ledger types.
- `Coins/Engine`: reward calculation and state transitions.
- `Coins/Store`: observable app state, persistence, speech, and UI-facing actions.
- `Coins/Views`: SwiftUI player and game-master screens.
- `Coins/Documents`: JSON file import/export wrapper.
- `CoinsTests`: unit tests for reward behavior.
- `project.yml`: XcodeGen source of truth for the Xcode project.
- `scripts/regenerate_project.sh`: regenerates `Coins.xcodeproj` and pins the project format for Xcode 15.4.
- `log.md`: dated work log.

## Local development

```sh
./scripts/regenerate_project.sh
xcodebuild -scheme Coins -destination 'platform=iOS Simulator,name=iPhone 15' test
```

If Xcode lists a different simulator set, use:

```sh
xcodebuild -scheme Coins -showdestinations
```

Then substitute an available destination into the test command.
