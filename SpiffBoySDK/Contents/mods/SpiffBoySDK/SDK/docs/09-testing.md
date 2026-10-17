# 9. Testing

Most mistakes can be found offline, in seconds, before you start Project Zomboid. The SDK gives you three ways to test, from the fastest to the most complete:

1. The robot, offline: it plays your cartridges with random buttons for thousands of ticks and reports crashes, draw calls and saves.
2. The text checker, offline: see [Texts and translations](06-texts-and-translations.md#checking-your-texts).
3. The game itself, with the developer menu and the log.

The offline tests are Python scripts of the kit. Run them from the `SDK` folder of the SpiffBoy SDK mod, where `tests/...` names them; the [Tools reference](13-tools-reference.md#folders) says where that folder and the media folders are.

## The robot

`tests/robots/run_robots.py` loads the real code of SpiffBoy and of your mod in a Lua 5.1 interpreter outside the game, starts each of your cartridges on a screen that counts every draw call, and plays it: on every tick it presses one of the seven buttons at random, sometimes held, sometimes tapped. It needs Python 3 with lupa.

```
python tests/robots/run_robots.py <SpiffBoy media folder> <mod media folder> [--games A,B] [--ticks N] [--seed N] [--json file] [--compare file]
```

The SpiffBoy media folder is the `42/media` folder of the SpiffBoy mod, the mod media folder the one of your mod, `.../mods/MyMod/42/media`. To play the examples of the SDK, give `../42/media` as the mod media folder. The robot plays every game that has a `lua/shared/<Ns>/Games/<Id>/Definition.lua`, and loads its `lua/client/<Ns>/Games/<Id>/Game.lua`: keep these names. Its options are listed in the [Tools reference](13-tools-reference.md#testsrobotsrun_robotspy); by default it plays 20000 ticks per game, about five and a half minutes of play.

### Reading the output

On the SDK, with 3000 ticks:

```
HelloSpiffBoy  ok     frames   3000  most calls  38  saves  385  ed1f1ba35d48
SpiffPong      ok     frames   3000  most calls  50  saves   25  0becc6dd124e
console texts missing: 0
```

| Column | Meaning |
|---|---|
| `ok` | No crash, no frame over the limit. Otherwise `CRASH` or `OVER CALLS`, and the line ends with the stage and the message of the error. |
| `frames` | Ticks played: fewer than `--ticks` when the game crashed. |
| `most calls` | The busiest frame seen, in draw calls. It must stay well under 300. |
| `saves` | How many times the game called `persist`. A game that saves its best score shows more than 0; one that saves every tick shows a number close to the ticks played. |
| digest | A fingerprint of every draw call of every frame and of every write the game made to the chip registers, in order. |

Lines starting with `SpiffBoy:` can appear before: they are the log of the console, such as `SpiffBoy: the game SpaceRace has no text Hi` for a key missing from `EN.json`. `console texts missing` counts texts of the console itself and stays 0.

The robot exits with an error when a game crashed, went over the limit or, with `--compare`, differs from the reference.

### Proving that a change changes nothing: --compare

Two runs with the same ticks and seed give the same digest when the game draws the same thing. This makes the robot a safety net for cleaning up code:

1. Before changing anything, save a reference:

   ```
   python tests/robots/run_robots.py <SpiffBoy media> <mod media> --games SpaceRace --json before.json
   ```

2. Make your change: rename variables, split a file in two, simplify a function.
3. Run again with `--compare`:

   ```
   python tests/robots/run_robots.py <SpiffBoy media> <mod media> --games SpaceRace --compare before.json
   ```

`same as reference` at the end of the line means that over the whole run your game drew exactly the same frames. `DIFFERS FROM REFERENCE` means the change did something: what you want when you change the game on purpose, a warning when you did not mean to.

This works only because the game takes its chance from `self.random`, which the robot seeds with `--seed` ([How a cartridge works](02-how-a-cartridge-works.md#the-random-generator)).

### What the robot does not see

- It runs standard Lua 5.1, not Kahlua. It removes `next`, which the game lacks, and turns a `string.char` code above 255 into `?`, so a link message built from such a code shows up; but `%` on a negative number gives the standard result, unlike the game ([Kahlua and pitfalls](10-kahlua-and-pitfalls.md)).
- Its pictures are fake: every texture is 40x6 pixels and nothing is drawn. It counts calls; it does not look at your art.
- It plays alone: the link cable is always unplugged.
- It presses buttons at random. A screen that needs a precise sequence may never be reached: raise `--ticks`, try other seeds, or start your game on the screen you want to test while you test it.
- Tunes played through the sequencer do not enter the digest; only direct writes to the chip (`self.chip:write`, `self.chip:loadWave`) do. A tune name that was never registered still crashes the game, and the robot reports it.

## Testing the link cable offline

`tests/spiff_pong/run_link_test.py` plays Spiff-Pong on two consoles joined by a simulated cable, with 1, 6 and 12 ticks of delay, a second player who joins late, a cable pulled in the middle of a match, and one console alone. A linked match passes when both consoles computed the same ball, paddles and score after every tick:

```
cable 6 ticks        ok     frames   2260  most calls  43  delay 9, score 7-3/7-3, longest rally 3, 2167 ticks compared, stalls 0
```

It tests Spiff-Pong only, but `tests/spiff_pong/link_test.lua` is a model for a game of your own on the cable: two runtimes, two ports passing messages with a delay, and a comparison of the two worlds after every tick.

## Every test at once: run_all.py

`tests/run_all.py` runs the robot with three seeds, the text checker, then the tests of the SDK itself, and prints one line per suite:

```
python tests/run_all.py <SpiffBoy media folder> <mod media folder>
```

```
ok    robots seed 12345
ok    robots seed 2718
ok    robots seed 31337
ok    check_texts
ok    dev_menu/run_dev_menu
ok    spiff_pong/run_link_test

all suites passed
```

On your own mod, the `dev_menu` and `spiff_pong` suites print `skip`: they test parts of the SDK. See [Tools reference](13-tools-reference.md#testsrun_allpy) for the options.

## Testing in the game

### The developer menu

The **SpiffBoy SDK** window ([Getting started](01-getting-started.md#the-developer-menu)) lists every cartridge registered by every loaded mod. If yours is missing, its `Definition.lua` did not run: look in the log. Useful habits:

- **In a console** gives a console with your cartridge inside and a fresh, empty save.
- Two loose cartridges of your game show whether each keeps its own save.
- A link cable and a second player, local or on a server, test the two player mode.

### The log: console.txt

Everything the console writes goes to the log of Project Zomboid, `C:\Users\<you>\Zomboid\console.txt` (`~/Zomboid/console.txt` on Linux and macOS). Search it for `SpiffBoy:`:

| Line | Meaning |
|---|---|
| `SpiffBoy: the game <Class> crashed in <stage>: <message>` | Your game raised an error in `init`, `tick` or `draw`, and the console froze. The message usually names the file and the line. |
| `...a frame went past 300 draw calls` | Inside a crash line: too many draw calls in one frame. |
| `SpiffBoy: no game class named <name>` | The `game` field of the definition names a class that does not exist: a misspelling, or `Game.lua` failed to load (look for an error above). |
| `SpiffBoy: the game <Id> has no text <Key>` | A text key missing from `EN.json`. |
| `SpiffBoy: missing texture <path>` | `context.art` did not find a picture. Check the name and the `art` folder. |
| `SpiffBoy: pixel font has no glyph for code point <n>` | A character of one of your texts is not in the font. |
| `SpiffBoy: tune <Id>.<name>, voice <voice>, character <n>: ...` | A mistake in the notation of a tune. |
| `SpiffBoy: <Id> has no tune named <name>` | Inside a crash line: the game played a tune it never registered. |
| `SpiffBoy: cartridge <Id> needs ...` | A field of the definition is missing or malformed. |
| `SpiffBoy: cartridge <Id> needs a newer SpiffBoy (api <n>, this SpiffBoy has <m>)` | The `api` of the definition is above the version of the installed SpiffBoy. |
| `SpiffBoy: cartridge <Id> of the mod <Mod> uses an id already registered by the mod <Other>` | Another mod registered a cartridge with the same id: choose another id. |
| `SpiffBoy: cartridge <Id> of the mod <Mod> uses the item <Type> already used by the cartridge <Other> of the mod <OtherMod>` | Another cartridge registered the same item; the same line with `game` names a game class used twice. |
| `SpiffBoy: tunes are registered under the id of a registered cartridge, and no cartridge has the id <Id>` | `SpiffBoy.Tunes.register` got an id no definition registered: a misspelled id, or a definition that failed. |
| `SpiffBoy: tunes are already registered under the id <Id> ...` | `SpiffBoy.Tunes.register` ran twice for the same game. |
| `SpiffBoy: the game <Id> cannot save, the save ...` | Inside a crash line: the save broke a limit and `persist` refused it ([Saving](05-saving.md#what-a-save-can-hold)). |
| `SpiffBoy: the texts of <Id> in <LANG>, file <path> of the mod <Mod>, cannot be read: ...` | Inside a crash line: a language file of your game is not valid JSON. Run `check_texts.py`. |
| `SpiffBoy: cartridge <Id> of the mod <Mod> has the item <Type> without the tag spiffboy:cartridge: ...` | The item script lacks the cartridge tag ([Dismantling](08-the-cartridge-item.md#dismantling)). |
| `SpiffBoy: cartridge <Id> of the mod <Mod> names the item <Type>, which no item script defines` | The `item` field and the item script disagree. |

An error in a file that loads at start, outside your game, appears as a Lua error with a stack trace: search for `STACK TRACE` and the name of your file.

`print("SpaceRace: score " .. tostring(self.score))` writes your own line in the log while you develop. Prefix your lines with the name of your game to find them, and do not print in every tick: the log grows fast.

Next: [Kahlua and pitfalls](10-kahlua-and-pitfalls.md).
