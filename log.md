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

## 2026-05-31 prototype schema cleanup
removed compatibility code while the app has no users:
- deleted legacy snapshot decoders and migration-only model types
- switched the current schema to synthesized codable implementations
- removed an unused cash-out event field
Up next:
- decide whether server sync needs config revision history

## 2026-05-31 daily definition cleanup
trimmed unused game-state data:
- renamed the daily completion milestone type to `DailyDefinition`
- stopped persisting denied lockout taps while keeping engine-side lockout enforcement
Up next:
- decide whether server sync needs config revision history

## 2026-05-31 special achievement catalog
expanded achievements beyond simple counters:
- added a 29-item menu with lesson patterns and calendar surprises
- added grouped game-master toggles for available achievements
- evaluate today's ordered activity log once per tap, then check each enabled rule
- verified 15 reward-engine tests on the iphone 15 simulator
Up next:
- polish achievement celebration presentation

## 2026-06-03 reward scope cleanup
removed prototype scope creep from rewards:
- deleted achievements and treasure chest random drops
- kept activities, daily bonuses, streaks, cash-out, and reward history
Up next:
- rebuild on the simulator and keep tuning the core daily loop

## 2026-06-06 daily repetition presets
added activity-scoped daily repetition configuration:
- added high (3x), medium (5x), and none presets
- added per-activity daily maximums of 1, 5, 12, or 20
- greyed out maxed activities and verified reward-engine tests on iphone 13 mini
Up next:
- review the game-master activity editor on small screens

## 2026-06-06 unlimited daily maximums
refined activity daily maximum settings:
- added a no-limit maximum option
- clarified repetition preset labels with threshold and coin values
Up next:
- review the game-master activity editor on small screens

## 2026-06-06 test-friendly activity defaults
changed activity defaults for faster manual testing:
- set seed and new-activity lockouts to 5 seconds
- set all default repetition presets to high
- removed default daily completion limits
Up next:
- reset seed data in the simulator before manual testing

## 2026-06-06 game-master save and icons
polished the game-master activity editor:
- added emoji activity icons for hands, feet, violin, piano, and notes
- pinned save configuration to the bottom with a visible saved confirmation
Up next:
- manually try icon picking and saving on the iphone 13 mini

## 2026-06-06 sf-symbol icon cleanup
kept game-master icon choices on sf symbols:
- replaced emoji additions with hand, finger, piano, and multiple-note symbols
- omitted violin and foot because they are not available as matching sf symbols
Up next:
- manually try icon picking and saving on the iphone 13 mini

## 2026-06-06 daily streak rewrite
rewrote streaks around daily completion tiers:
- removed interval streak configuration
- added daily minimum presets, bonus presets, break allowance, and manual level corrections
- verified 10 reward-engine tests on iPhone 13 mini
Up next:
- try the game-master streak controls on device-sized screens

## 2026-06-06 reward celebration tiers
made completion rewards feel distinct:
- split the completion overlay into base, repetition bonus, and streak bonus rows
- added separate symbols, particles, sounds, haptics, and longer timing for stacked rewards
- verified 10 reward-engine tests and simulator launch on iPhone 13 mini
Up next:
- tune exact sound choices on a physical device

## 2026-06-06 main merge
merged main into daily streak work:
- kept within-day repetition bonuses and daily maximums separate from across-day streak levels
- kept sf-symbol activity icons and pinned save controls
Up next:
- run reward-engine tests on iPhone 13 mini
