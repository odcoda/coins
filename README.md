# Coins

Native iOS reward game for turning real-world practice into a coin-collecting loop.

Coins is built for tasks that need repeated deliberate effort, such as instrument
practice, studying, chores, or project work. The app does not verify the real
world work; it gives a configurable reward loop around a trusted completion tap.

## Current MVP

- SwiftUI iPhone/iPad app
- Generated app icon in the iOS asset catalog
- Configurable activities with picker-based rewards and lockouts
- Same-day combo bonuses and configurable daily streak bonuses
- Always-visible coin balance with a reward fly-up animation
- Separate piggy bank page with streak and cash-out tracking
- Separate tracking page with recent rewards and reward-history charts
- Password-gated game-master panel
- JSON export/import of full app state

## App Flow

The player shell has a persistent top bar with the current coin balance. Swipe
right from the left edge, or use the top-left sidebar button, to reveal the
hidden navigation drawer for Main, Piggy Bank, Tracking, and Game Master.

The Main page is the activity loop. Tapping an activity awards its structured
coin reward, then checks for same-day combo bonuses and configured streak
bonuses. Positive rewards briefly show a centered coin message, then collapse
toward the top balance while the balance ticks upward.

Activity cards lock after a completion. The countdown refreshes every second on
the main screen, and a locked activity cannot be tapped again until the timer
expires.

The Piggy Bank page shows the larger balance context, earned streak level, cashed-out
dollars, pending cash-out value, and the cash-out control.

The Tracking page shows today and lifetime stats, recent reward events, a
rewards-by-day bar chart, and a cumulative coins line chart. These charts are
built from immutable reward history.

Game Master is opened from the drawer. The seeded password is `1234`. Game
Master currently supports speech mode, adding/removing/editing activities,
picker-based activity reward/lockout edits, configurable activity-scoped daily
streaks, manual streak-level adjustments, icon selection for activities and
streaks, balance adjustments, JSON import/export, seed reset, and changing the
game-master password.

Cash Out does not remove coins from the piggy bank. It records how many new coins
have been converted to earned dollars since the last cash-out, using the
configured N coins for $X.YZ ratio.

## Reward Model

Reward behavior lives in [RewardEngine.swift](Coins/Engine/RewardEngine.swift).
The engine is intentionally deterministic when tests pass explicit dates.

- `ActivityDefinition` gives the known structured reward, lockout, repetition
  bonus preset, and daily maximum.
- Daily repetition bonuses are activity-scoped presets: high (3x), medium (5x),
  or none.
- Daily maximums can be 1, 5, 12, 20, or no limit, and only cap repetitions
  within the same day.
- `DailyDefinition` triggers from qualifying completions during the current day.
- `StreakDefinition` advances across days when its chosen activities meet the
  configured daily minimum. Presets define 2-, 3-, 5-, and 7-day bonus tiers,
  with optional break allowance after a tier has been earned.
- `StreakProgress` records each streak's current earned tier and last update.
- `ActivityEvent` records completed real-world activities.
- `RewardEvent` records rewards, adjustments, and cash-out events.

## Persistence And Sync

The app stores a `GameSnapshot`, which contains the current `GameConfig` and an
event-backed `GameState`, as JSON in app support storage. Balance, progress,
and daily counts are derived from the event histories. Earned streak tiers are
stored as compact state because break allowance depends on the user's full
history. Game Master's export/import actions use the same snapshot format, so a
complete local game can be backed up, restored, or moved to another device
manually.

Longer term, this snapshot shape is the natural boundary for server sync: send
operations or snapshots to a backend, then reconcile into `GameSnapshot`.

## Repo Layout

- `Coins/App`: app entry point.
- `Coins/Models`: codable config, state, activity, and reward-event types.
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
xcodebuild -scheme Coins -destination 'platform=iOS Simulator,name=iPhone 13 mini' test
```

If Xcode lists a different simulator set, use:

```sh
xcodebuild -scheme Coins -showdestinations
```

Then substitute an available destination into the test command.

## Install On An iPhone

1. Install Xcode 15.4 or newer, then sign in with an Apple ID under Xcode
   Settings > Accounts.
2. If you need a personal bundle id, change `PRODUCT_BUNDLE_IDENTIFIER` in
   `project.yml` to something unique, then run `./scripts/regenerate_project.sh`.
3. Open `Coins.xcodeproj` in Xcode.
4. Select the Coins app target, open Signing & Capabilities, and choose your
   development team. Xcode should create the provisioning profile.
5. Plug in the iPhone, trust the Mac on the phone, and enable Developer Mode if
   iOS asks for it.
6. Pick the iPhone from Xcode's run destination menu and press Run.
7. If the phone blocks launch, open Settings > General > VPN & Device Management
   and trust the developer profile.

Free Apple developer provisioning usually expires after 7 days. A paid Apple
Developer Program account is the cleaner path for longer-term on-device use or
TestFlight distribution.
