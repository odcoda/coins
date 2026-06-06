Everyone in my family, including myself, struggles with motivation for tasks that require deliberate effort over long periods of time to achieve results. The specific motivating example is helping my son practice his musical instrument. But I'd like this to be sufficiently general that I could use it for e.g. studying or personal projects as well. He likes to do tasks that involve consistent rewards and loot-box/variable rewards in other settings (e.g. an online math class he takes) and we want to replicate this gamification.

Make it a game. There should be cute animations for success, sound effects, pretty backgrounds, etc. If we're feeling ambitious the entire "theme" of the game could be swappable (e.g. instead of treasure chests and collecting coins, it could be rocket ships and collecting stars, RPG characters and "experience points", etc. But focus on just the coin theme to start. The core mechanic is just about receiving rewards for real-world activities. (Note: there is no verification that the real-world activities were done, beyond some primitive "lockouts" and "cheating detection")

It should be a native application for ios (especially iphone, but also ipad support would be nice). Please don't implement it as a web app, I'd like it to be nicer / smoother than that especially for the animations above.

The exact reward structure should be configurable, but here are some ideas for knobs

(1) Structured rewards. Most activities (e.g. practicing a specific song) should give a sepecific reward which is known ahead of time. e.g. 1 coin for practicing one time. These should be configurable by the "game master" depending on where things are.

(2) Consistency and streaks. There should be additional bonuses for streaks, both within a day and across days. These can be structured as a set of "streaks" which flash when obtained, but we can also tell the user when they're close so they don't give up.


All the actual numbers involved, as well as what activities they describe, the streaks we want available, and the probability distributions for each of the random things above. The game master mode configures this.

The game master to change the number of activites, as well as their
text -- there should be buttons to add and remove activities

The streaks should be configurable -- the game master should be able to
add/remove/configure one or more achievable streaks. See streaks.md for details of the streaks.

Talking: since this is being made for kids as well as adults, there should be a mode where all the text that shows up in activities, achievements, etc is read aloud.

Lockout: the user shouldn't be able to spam completions. There's a configurable lockout after they tap each thing.

Piggy bank: the user can see how many coins they've collected.

Password protection: the game master mode needs a special password to access. From there, all the all the configuration is opened. There are also options to revert / rewind coins (if the user cheats), or adjust the balance another way.

History editor: sometimes we need to record things after the fact, or fix mistakes in our recording. See history_editor.md for more about this.

"Cash Out": this is an operation where the coin balance stays the same but we keep track of how much the user has "cashed out" into real money. This basically keeps the rewards going up but also shows how much the user has earned in real money. The conversion ratio should be configurable not 1:1.

Sync: the entire game state (including the configured activites, rewards for them, variable rewards, streak state, etc) should be exportable to / importable from json. At some point we should add a server and login and have all operations sync to/from the server. I'm not sure what the simplest way to do this syncing is though. Maybe I can put something really dead simple on aws? or get my own single virtual server and use it for everything? (I'm planning to have a bunch of different apps which are basically all going to want to sync in the same ways).

Some ideas we tried but were later removed:

- Intermittent variable / surprises. (This part feels a little too sneaky, we can include it or not). Once in a while, but only if the structured and consistency parts are doing well enough, we can throw in a bonus variable reward. Call it a "treasure chest" or something.

-  Additional achievements! These can flash on the screen when they're activated.
