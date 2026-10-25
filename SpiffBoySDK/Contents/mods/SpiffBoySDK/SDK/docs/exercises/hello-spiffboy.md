# Hello SpiffBoy exercises

These exercises change Hello SpiffBoy one step at a time. Do them in order: each one uses what the previous ones taught. In `Game.lua`, a comment such as `-- Exercise 3: ...` marks the code each exercise touches, and a worked solution for each is in [solutions/](solutions/). Try on your own first.

## Before you start

The files of the game, under `42/media/` in the folder of the SpiffBoy SDK mod, the SDK media folder:

| File | Content |
|---|---|
| `lua/shared/SpiffBoySDK/Games/HelloSpiffBoy/Definition.lua` | Registers the cartridge. |
| `lua/shared/SpiffBoySDK/Games/HelloSpiffBoy/Translate/EN.json` | The English texts of the game. |
| `lua/client/SpiffBoySDK/Games/HelloSpiffBoy/Game.lua` | The game: rules in `tick`, drawing in `draw`. |
| `lua/client/SpiffBoySDK/Games/HelloSpiffBoy/Music.lua` | The music and the sound effects. |
| `ui/SpiffBoySDK/Games/HelloSpiffBoy/spiffo.png` | The head of Spiffo, a layered sheet of three cells. |

You can check your work in two ways. In the game, take Hello SpiffBoy **In a console** from the developer menu and play it. Offline, run the robot from the `SDK` folder of the mod:

```
python tests/robots/run_robots.py "<SpiffBoy media folder>" "../42/media" --games HelloSpiffBoy
```

[Tools reference](../13-tools-reference.md#folders) says where the SpiffBoy media folder is.

Steam puts back the original files of a subscribed mod whenever it updates it: keep a copy of the files you change.

A good result says `ok`, shows `most calls` well under 300 and prints no line containing `has no text`. Before an exercise, save a reference with `--json before.json`; after your change, run again with `--compare before.json`. `DIFFERS FROM REFERENCE` then shows that your change did something, and `same as reference` that a change meant to be invisible really was.

## Exercise 1: change the speed of Spiffo

Make Spiffo move twice as fast. The constant `SPEED` sits near the top of `Game.lua`, and `tickPlay` uses it.

`tick` runs 60 times per second, so with `SPEED = 1` Spiffo moves 60 pixels per second. `input:axes()` returns -1, 0 or 1 for each direction; multiplied by `SPEED`, it gives the pixels to move this tick.

In the game, Spiffo now crosses the playfield in about a second and a half instead of three. The robot still says `ok`, and `--compare` says `DIFFERS FROM REFERENCE`.

To go further, make Spiffo faster only while A is held. That needs `input.held.a`, not `input.pressed.a`: `pressed` is true for one tick, `held` for as long as the button stays down.

## Exercise 2: wrap around the edges

When Spiffo walks off one edge of the playfield, he comes back on the opposite edge. The function to change is `moveSpiffo`.

Today `clamp` stops Spiffo at the edges; replace it with a wrap. The usual trick is the remainder, `(x + width) % width`, but in the Lua of the game `%` keeps the sign of the left side: `-1 % 180` is `-1`, not `179` ([Kahlua and pitfalls](../10-kahlua-and-pitfalls.md#modulo-keeps-the-sign-of-the-left-side)). Add the width before taking the remainder, as `tickTitle` does for the menu cursor. The playfield does not start at 0 vertically: wrap `y - PLAY_TOP`, then add `PLAY_TOP` back.

Check it in the game by holding left: Spiffo leaves on the left and comes in on the right. The robot runs standard Lua, where a wrong wrap does not show, so watch it in the game.

To go further, let Spiffo show half on each side while he crosses an edge, by drawing him a second time one playfield width away, and count the draw calls this costs.

## Exercise 3: a random greeting

The bubble says one of three greetings, chosen at random on each press of A, all three from the translation file. You will touch `EN.json`, then `sayHello` and `drawBubble` in `Game.lua`.

Add two keys to `EN.json`, for example `"Hi": "HI THERE!"` and `"Hey": "HEY!"`. Keep a list of keys, `{ "Hello", "Hi", "Hey" }`, and pick one in `sayHello` with `self.random:int(1, 3)`, never with `math.random` or `ZombRand` ([the random generator](../02-how-a-cartridge-works.md#the-random-generator)). Store the chosen key in `self.greeting` and let `drawBubble` call `gameText(self.greeting)`: the choice belongs to `tick`, and `draw` only reads it.

In the game, press A several times: the bubble changes. The robot prints no `has no text` line; a key forgotten in `EN.json` would print `the game HelloSpiffBoy has no text Hi`. `check_texts.py` now lists the two keys as missing in the 28 other languages, which show them in English until they are translated.

To go further, add the two keys to `FR.json` and play the game in French: the bubble follows, with no change to the Lua.

## Exercise 4: a different effect every tenth hello

Every tenth hello plays a longer, happier effect instead of the usual one. You will touch the names and the call to `SpiffBoy.Tunes.register` in `Music.lua`, then `sayHello` in `Game.lua`.

A new effect needs a name (`Music.CHEER = "cheer"`) and a tune under that name in `register`; the commented example in `Music.lua` is a start. Give it `pulse2`, the voice the music leaves free, so it never cuts the melody. "Every tenth" means that the remainder of the count by 10 is 0; the count is never negative, so `%` is safe here.

In the game, count to 10: the tenth press sounds different. If you misspell the name in `Game.lua`, the robot with its default seed reports a `CRASH` naming the unknown tune, because the sequencer refuses names nobody registered. Some seeds never reach a tenth hello in one visit and miss it: run the robot with a few seeds.

To go further, play a short jingle as the music when the player beats the best count, then start the theme again ([Music after a jingle](../04-sound-and-music.md#music-after-a-jingle)).

## Exercise 5: save a new value

Keep the total number of hellos ever said on this cartridge, and show it on the title screen. Look at `readBest` as a model, then at `init`, `saveRound` and `drawTitle`, and at `EN.json`.

Put a number in the save (`self.save.total`). Read it the way `readBest` does: the save of an older cartridge has no `total`, so check its type and start from 0. Add the count of the round to it in `saveRound`, the moment the player confirms the end of a round, so it goes to the cartridge in the same `persist` as the best count ([When to save](../05-saving.md#when-to-save)). A round given up with Start adds nothing. The title has no free line left: alternate the best count and the total every two seconds, as `drawPlay` does with its hint line.

In the game, play a round to its end and confirm it, then switch the console off and on: the total is still there.

To go further, add a menu entry that erases the best count and the total after a yes or no question.

## Exercise 6: a second sprite that follows

A second Spiffo follows the first one around the playfield, a little slower. You will touch `enterPlay`, `tickPlay` and `drawPlay`.

The follower needs its own position, `self.buddyX` and `self.buddyY`, set in `enterPlay`. In `tickPlay`, move it one pixel toward Spiffo on each axis every other tick (`self.ticks % 2 == 0`), and only while it is farther than one head away, so it never sits on top of him. Draw it with the same sheet and `drawSpiffo`, before Spiffo so Spiffo stays in front; the blinking cell, or only the shades `{ 1, 2 }`, tells the two apart.

In the game, the buddy trails behind Spiffo. The robot shows `most calls` a little higher than before, one call per shade drawn for the new head, and still far under 300.

To go further, make a chain of five buddies, each following the one before it, and work out its cost in draw calls.

## Exercise 7: a pause screen

Start pauses the round instead of giving it up. On the pause screen, Start resumes and B gives the round up and goes back to the title. You will touch `tickPlay`, `drawPlay` and `EN.json`.

Add a flag `self.paused`, false in `enterPlay`. At the top of `tickPlay`, when paused, read only Start and B, then `return` so nothing else moves, the clock of the round included. Stop the music on pause with `self.sequencer:stop()`, and start it again on resume with `self:applyMusic()`, which respects the music option. Add a key `"Paused": "PAUSED"` to `EN.json` and draw it in a box in the middle of the screen while the flag is set, the way `drawBubble` draws its box. `tickBlink` runs in `tick` on every screen: decide whether Spiffo may blink during the pause.

In the game, press Start during play: everything freezes and the music stops, and Start again resumes where you were. The robot still says `ok` and prints no `has no text` line.

To go further, show a hint on the pause screen (`START RESUME  B MENU`) and make the box blink every half second.
