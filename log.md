## 2026-05-16 coins bootstrap
started the native ios app scaffold and first reward loop:
- added swiftui app structure with xcodegen
- implemented rewards, streaks, treasure chests, cash-out, and json sync
- added a password-gated game-master panel and engine tests
- verified app build plus test-bundle build-for-testing on the ios simulator sdk
Up next:
- expand the game-master editor and polish animations/audio
- run the tests on a live simulator once CoreSimulator is available

## 2026-05-16 simulator tests passing
ran the live iphone 15 simulator tests and fixed combo rewards:
- combo milestones now trigger from total daily completions
- reward engine tests pass on ios 17.5 simulator
Up next:
- expand the game-master editor and polish animations/audio

## 2026-05-16 main screen polish
improved the first-run app ergonomics:
- lockout timers refresh every second on the player screen
- connected game master through the top-right gear button
- expanded the readme with repo and app behavior notes
Up next:
- make game-master activity editing more complete

## 2026-05-16 simulator launch fix
stabilized simulator launch configuration:
- replaced generated app plist with an explicit Info.plist
- fixed Swift 5.10 project generation quoting
- verified clean simulator build, install, launch, and tests
Up next:
- retry Xcode Run from the UI

## 2026-05-17 game shell polish
split the player experience into game pages:
- added persistent top-bar coin balance and reward fly-up animation
- moved piggy-bank/cash-out and tracking views behind a swipe drawer
- added daily reward and cumulative coin charts from the ledger
- verified simulator tests on iphone 15
Up next:
- add more game feel with sound and theme-specific reward effects

## 2026-05-17 game-master configurability
expanded reward configuration:
- changed activity rewards and lockouts to pickers
- added activity add/remove controls
- added configurable activity-scoped streaks with frequency and growing rewards
- verified simulator tests on iphone 15
Up next:
- polish game-master editing ergonomics on small screens

## 2026-05-17 game-master icon polish
refined game-master editing controls:
- added interval streak frequencies for every 2-5 days and every 2-4 weeks
- changed remove controls to small red trash icons
- added icon pickers for activities and streaks
- verified simulator tests on iphone 15
Up next:
- verify the icon picker flow on device-sized screens

## 2026-05-17 trash icon labels
cleaned up game-master delete controls:
- kept activity and streak delete buttons icon-only
- renamed hidden accessibility labels away from "Remove"
Up next:
- verify the icon picker flow on device-sized screens

## 2026-05-17 app icon
generated and installed the first ios app icon:
- added an app icon asset catalog with iphone/ipad sizes
- wired XcodeGen to compile AppIcon
- documented phone install steps
Up next:
- try the app on a physical iphone

## 2026-05-25 architecture review
reviewed the current ios app structure and reward-state flow:
- mapped the model, engine, store, persistence, and SwiftUI screen boundaries
- identified persistence and configuration gaps for follow-up review
Up next:
- address the highest-risk review findings

## 2026-05-30 xcode target inspector crash
fixed Xcode 15.4 project metadata generation:
- replaced the patched Xcode 16 project format with XcodeGen's native Xcode 15.3 format
- removed the explicit blank development team so signing can be configured in Xcode
Up next:
- select a development team and run the app on an iphone

## 2026-05-31 event-backed game state
simplified the game-state model around immutable histories:
- replaced cached progress, streak, unlock, balance, and ledger fields with derived values
- recorded completed activities, rewards, denied lockout taps, and reward provenance
- migrated old json ledger exports and fixed local iso8601 snapshot loading
- verified 11 reward-engine tests on the iphone 15 simulator
Up next:
- decide whether server sync needs config revision history
