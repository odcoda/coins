# Coins

Native iOS reward game for turning real-world practice into a coin-collecting loop.

## Current MVP

- SwiftUI iPhone/iPad app
- Configurable activities with lockouts and fixed rewards
- Same-day combo bonuses and day-over-day streak bonuses
- Surprise treasure chests gated by streak/completion thresholds
- Achievement unlocks
- Piggy bank balance plus cash-out tracking
- Password-gated game-master panel
- JSON export/import of full app state

## Local development

```sh
./scripts/regenerate_project.sh
xcodebuild -scheme Coins -destination 'platform=iOS Simulator,name=iPhone 15' test
```

The seeded game-master password is `1234`. Change it in the app before real use.
