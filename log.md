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
