# Exercises

Two sets of exercises, in order of difficulty.

## Hello SpiffBoy exercises

Seven guided exercises on the smallest cartridge of the SDK, each with hints, a way to check your work, and a worked solution in [solutions/](solutions/). Do them after pages 1 to 6 of the documentation: [open the Hello SpiffBoy exercises](hello-spiffboy.md).

| # | Exercise | You practise | Solution |
|---|---|---|---|
| 1 | Change the speed of Spiffo | constants, `tick`, `axes()` | [01-speed.lua](solutions/01-speed.lua) |
| 2 | Wrap around the edges | positions, `%` with negative numbers in Kahlua | [02-wrap.lua](solutions/02-wrap.lua) |
| 3 | A random greeting | `self.random`, texts in `EN.json` | [03-random-greeting.lua](solutions/03-random-greeting.lua) |
| 4 | A different effect every tenth hello | registering a tune, `sequencer:effect` | [04-tenth-effect.lua](solutions/04-tenth-effect.lua) |
| 5 | Save a new value | `self.save`, `persist`, reading a save safely | [05-save-total.lua](solutions/05-save-total.lua) |
| 6 | A second sprite that follows | layered sheets, draw calls | [06-follower.lua](solutions/06-follower.lua) |
| 7 | A pause screen | screens and modes, stopping the music | [07-pause.lua](solutions/07-pause.lua) |

## Spiff-Pong challenges

Open challenges on the complete cartridge, without solutions. Read the [Spiff-Pong walkthrough](../12-spiff-pong-walkthrough.md) first. Before each one, save a reference with the robot (`--json before.json`); after it, run the robot with `--compare` and the link test (`tests/spiff_pong/run_link_test.py`), to see that you changed what you meant to and nothing else.

### 1. A difficulty option

Add a fourth option, CPU, with three levels: easy, normal, hard.

The strength of the console player lives in `Brain.lua`: `AIM_ERROR` (how far off the ball it aims) and `REST_EVERY` (it rests one tick in that many). Turn them into settings given to `Brain.new`. Then add an entry to `Options.ENTRIES` and a default to `Options.DEFAULTS`, and read the new field in `Options.read` with the same checks as the others: old cartridges have no such field, so the default must apply. The texts go in `EN.json`; run `check_texts.py` afterwards. The option concerns only the match against the console, so the two player match must not read it.

### 2. A rally counter

Show the number of hits of the current rally under the score, and make it blink when it beats the best rally of the table.

`match.rally` already counts the hits; draw it with `screen:number` and the digits strip, like the score, in a softer shade. The best rally is `self.records.rallies[1]`, which is nil on a new cartridge. Blinking can use the clock of the game, `math.floor(self.clock / 8) % 2`, read in `draw` without changing any state. Expect one more draw call per digit in the robot output.

### 3. A ball with a trail

Draw the three previous positions of the ball behind it, in lighter and lighter shades.

`draw` must not change the state, so keep the history in `tick`: after each `match:tick`, push the position of the ball into a list of three held by the game, not by `Match`, and shift a fixed list rather than creating tables every tick. On the cable the trail is decoration only and lives outside the match; work out why that keeps both consoles in step. Each dot is one more draw call.

### 4. A smash on B

Holding B at the moment the ball hits your paddle sends it back faster.

This changes the rules, so it belongs in `Match.lua`: `Match:tick(left, right)` must receive B with up and down, and `Match:bounce` must read it. The console player must be able to smash too, or at least `Brain:think` must return `b = false`. On the cable, B must travel: `Link:sendInput` packs up as 1 and down as 2 in one byte; add 4 for B and unpack it in `unpackInput`. If the two consoles disagree, the checksums of the link test will show it. A smash deserves its own sound: a new event kind from the match and a new tune in `Music.lua`.

### 5. Best scores per speed

Keep a separate table of the five longest rallies for each ball speed, and show the table of the current speed.

In `Records.lua`, `records.rallies` becomes one list per speed, stored under keys such as `s1`, `s2` and `s3` in `save.records`. Old cartridges have one list without speed: decide whether to drop it or to treat it as the normal speed, and write `read` so it handles both shapes. Three tables of five short texts and two counters stay far under the 512 entries of a save. The best scores screen should show which speed it lists; left and right could switch between the three tables.
