let's add a new "history editor" screen to the app, gated by the same game master password, where

(1) we show a calendar-style grid with different boxes for each recent day. Boxes with activities should have color, boxes without should not. Use darker colors for more activity. (this is inspired by the github activity tracker ui).

by default show the last 30 days in a grid (with columns for weeks sunday - saturday, like a calendar), but also have a calendar selector at the top where the user can select a date and we'll show the 30 days before that instead.

tapping on a date in the calendar grid should open a small pop up / hover box that shows the recorded activities the user did on that date, according to the current history, with a button in the hover box to open the per date editor (overlaying the entire page)

(2) the per date editor should allow the user to quickly rewrite the history of how many times each activity occurred on the day. For each activity, use a simple picker from 0-50. Show the difference between what's picked and the recorded history.

have a "save changes" button to change the history on that day

note that if the history changes, we should update the activity stream to match, so future game logic computes streaks, etc correctly!

to do this, delete events that were removed (cut later timestamps first). to add new events, give them a "manually added" marker instead of a timestamp (make this like an either-or type where it either has a real timestamp or it was manually added -- this may require some refactoring / changes in other places too)
