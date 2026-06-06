I. First and foremost, instead of having them be configurable in so many ways, let's have them always be daily. Remove all settings and logic about the streak interval. Just allow the game master to configure 3 settings:
(1) which activities contribute to the streak (toggles per activity)
(2) a total minimum for the day to count as complete for the streak (i.e. count of activities). Select from presets of 1, 3, 5, 12, 20
(3) a preset for bonuses and times. For now just have two settings:
preset A ("no-breaks"): 1 bonus coin for 2 consecutive days, 2 for 3, 3 for 5, 5 for 7
preset B ("breaks"): same as preset A, but the break allowance is 0 for 2 or 3 days, and 1 for 5 or 7 days. 

II. The break allowance idea is a new addition/change to the streak logic. The way streaks and breaks should work is that:
- as the user is building toward a streak, they have to complete every day. Each time, they earn the incremental bonus for that day (i.e., on the 2nd consecutive day, they get 1 bonus coin, then on the 3rd day, they get 2 more bonus coins, etc).
- once they have a given streak level, they can take breaks while maintaining it. That is, on the next day when they do the activity, if the number of breaks within the window of the last N days is no greater than the break allowance, they continue getting the same bonus for their previous streak level (e.g., if they did 5 days then took 1 day off, on their first day back they'd get the 5 day streak bonus again. They'd get the 5 day bonus on each of the next few days too. However, they'd have to then do 7 days without stopping to get the 7 day bonus on the 7th day).
- if they exceed the break allowance, their streak is lost and they have to start over from 0.

implementation notes: this is not straightforward to compute purely statelessly from the activity stream because the streak the user earns will rely on their full event history. To avoid excessive computation, for each streak, also track state the user's current streak level, as well as when that was most recently updated. At the moment when the user finishes the total minimum for a streak, look at their last recorded streak level / update time, the window of the last N days for the recorded level (to see if they lost their streak), and the window of the last M days for the next level up (to see if they moved up to the next level); in these cases you should update the streak level.

Similarly to the manual balance overrides, game master should be able to manually adjust the streak level in each streak (to allow for corrections, excused absences, etc).
