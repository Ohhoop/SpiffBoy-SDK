# 9. Testing

Most mistakes can be found offline, in seconds, before you start Project Zomboid. The SDK gives you three ways to test, from the fastest to the most complete:

1. The robot, offline: it plays your cartridges with random buttons for thousands of ticks and reports crashes, draw calls and saves.
2. The text checker, offline: see [Texts and translations](06-texts-and-translations.md#checking-your-texts).
3. The game itself, with the developer menu and the log.

The offline tests are Python scripts of the kit. Run them from the `SDK` folder of the SpiffBoy SDK mod, where `tests/...` names them; the [Tools reference](13-tools-reference.md#folders) says where that folder and the media folders are.

## The robot

`tests/robots/run_robots.py` loads the real code of SpiffBoy and of your mod in a Lua 5.1 interpreter outside the game, starts each of your cartridges on a screen that counts every draw call, and plays it: on every tick it presses one of the seven buttons at random, sometimes held, sometimes tapped, and now and then it pauses one to five seconds without touching any button, as a player who watches the screen. It needs Python 3 with lupa.

```
python tests/robots/run_robots.py <SpiffBoy media folder> <mod media folder> [--games A,B] [--ticks N] [--seed N] [--lang LANG] [--json file] [--compare file]
```

The SpiffBoy media folder is the `42/media` folder of the SpiffBoy mod, the mod media folder the one of your mod, `.../mods/MyMod/42/media`. To play the examples of the SDK, give `../42/media` as the mod media folder. The robot plays every game that has a `lua/shared/<Ns>/Games/<Id>/Definition.lua`, and loads its `lua/client/<Ns>/Games/<Id>/Game.lua`: keep these names. Given a folder that holds no such game, such as the `42` folder instead of `42/media`, it stops with a message. Its options are listed in the [Tools reference](13-tools-reference.md#testsrobotsrun_robotspy); by default it plays 20000 ticks per game, about five and a half minutes of play.

### Reading the output

On the SDK, with 3000 ticks:

```
HelloSpiffBoy  ok     frames   3000  most calls  40  saves    0  0c95240227cf
SpiffPong      ok     frames   3000  most calls  50  saves   25  6179d633001d
console texts missing: 0
```

| Column | Meaning |
|---|---|
| `ok` | No crash and no warning. `CRASH` means the game stopped: the line ends with the stage (`load <file>`, `init`, `tick` or `draw`) and the message of the error, such as `SB-DRAW-LIMIT` for a frame over 300 draw calls. `WARN` means the game played but asked for a picture or a text that does not exist, or drew a text off screen: the warnings follow under the line. |
| `frames` | Ticks played: fewer than `--ticks` when the game crashed. |
| `most calls` | The busiest frame seen, in draw calls. It must stay well under 300. |
| `saves` | How many times the game called `persist`. A game that saves on its own never gets here: its `persist` outside a press is a crash ([When to save](05-saving.md#when-to-save)). Hello SpiffBoy shows 0, because the robot presses Start often and gives every round up before its 30 seconds; `tests/hello/run_round_test.py` plays whole rounds instead. A game that ends at 0 saves gets a `note:` line under it: the robot never ran its saving, check it in a test of your own. |
| digest | A fingerprint of every draw call of every frame and of every write the game made to the chip registers, in order. |

Lines starting with `SpiffBoy:` can appear around them: they are the log of the console. `console texts missing` counts texts of the console itself and stays 0.

Under the line of a game marked `WARN`, each warning has a line of its own:

```
SpaceRace      WARN   frames  20000  most calls  32  saves    6  ab3d28bf403a
    text off screen: "BONJOUR SPIFFBOY, LE PLUS LONG DES TITRES" from x -25 to 205
    [SB-TEXT-MISSING] the game SpaceRace has no text Hi. Fix: add the key to EN.json and run check_texts.py. See: SDK docs/06-texts-and-translations.md, Checking your texts.
```

- `text off screen` names the first text the game drew past an edge of the screen, with where it starts and ends.
- `[SB-TEXT-MISSING]` is a key missing from `EN.json`.
- `[SB-ART-MISSING]` is a picture no file has with exactly that name, letter case included ([The art folder](03-screen-and-art.md#the-art-folder)); when a file has the name in another letter case, a line before it says so: `picture <file> exists as <file>`.
- `[SB-REG-ITEM]` and `[SB-REG-TAG]` are the checks the console makes on your item script when a game starts: no item script with the `item` of the definition, or an item without the tag `spiffboy:cartridge` ([The cartridge item](08-the-cartridge-item.md)).
- `class name` is a game class whose `derive` name differs from its global name ([The game class](02-how-a-cartridge-works.md#the-game-class)).
- `require("<path>") finds no file` is a `require` of a path under a folder of your mod that no file has; `finds <file> only in another letter case` is a file the game will not find on Linux and the Steam Deck.
- `[SB-GLYPH]` is a character of a text that the pixel font lacks: it is left out on the screen.
- `[SB-REG-TUNE] ... voice <voice> lasts <n> ticks` is a looping tune whose voices do not all have its length ([The notation](04-sound-and-music.md#the-notation)).
- `saves: <n> writes within ten seconds that change nothing in the save` counts the saves that write exactly what the save before held: more than 5 within ten seconds is a game that saves on its own presses, during play. Saves that change something, such as the options left after a change, never count ([When to save](05-saving.md#when-to-save)).
- `art("<name>") is called in draw` is a picture loaded while the game draws: load every picture once, in `init`.
- `getTexture called at <file>:<line>` (or `Texture.getSharedTexture`, `Texture.new`) is a picture loaded around `self.context.art`: the game may show a picture of Project Zomboid with the same name ([The art folder](03-screen-and-art.md#the-art-folder)).
- `draw changed self.<field>` is a field of your game, a number, a text or a boolean, that `draw` changed: the state of a game changes in `tick` only, or it runs faster on a faster computer. without the namespace of your mod at the start of its name ([The game class](02-how-a-cartridge-works.md#the-game-class)).

### Playing in another language: --lang

The robot plays in English unless `--lang` names another language of the game, such as `--lang FR` or `--lang JP`. The game then reads the texts of that language, so `most calls` counts their letters and `text off screen` shows a translation too long for its place. `run_all.py` plays every language your games have a file for.

The robot exits with an error when a game crashed, warned or, with `--compare`, differs from the reference.

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

This works only because the game takes its chance from `self.random`, which the robot seeds with `--seed` ([How a cartridge works](02-how-a-cartridge-works.md#the-random-generator)). A call from your game to `math.random`, `math.randomseed`, `ZombRand`, `os.time`, `os.clock`, `os.date` or `getTimestampMs` stops it in the robot with `SpiffBoy: [SB-REPEAT] <function> called at <file>:<line> ...`; in Project Zomboid they work, but they make a game impossible to repeat or to compare.

### What the robot does not see

- It runs standard Lua 5.1, not Kahlua. It removes `next`, which the game lacks, and turns a `string.char` code above 255 into `?`, so a link message built from such a code shows up; but `%` on a negative number gives the standard result, unlike the game ([Kahlua and pitfalls](10-kahlua-and-pitfalls.md)). Its strings hold bytes, so the position of an error in a language file, `at character <n>`, counts an accented letter as two or three: `check_texts.py` and the game count it as one.
- It does not look at your art. It checks that every picture your game asks for exists with exactly that name, letter case included, and, like the console, writes `SpiffBoy: [SB-ART-MISSING] missing texture <file>`, gives your game nil for a missing one and marks the game `WARN`. A picture it finds has its real size, but the robot draws nothing: it counts calls. To see a screen, take a picture of it in a test of your own with `console:screenshot` ([Writing a test of your own](#writing-a-test-of-your-own)).
- It starts every game with an empty save. Reading a save written by an older version of your game is not tested: start the game in Project Zomboid with a cartridge that holds such a save.
- Its `require` looks for files only in the Lua folders of SpiffBoy and of your mod. A path under a folder of your mod that no file has is a `WARN`; any other path it does not find, such as a file of the game itself, is skipped without a word. A file that it finds but that does not compile, or that raises an error while it loads, such as a tune written wrong, stops the game with `CRASH` and `load <file>`, naming the file.
- It plays alone: the link cable is always unplugged.
- It knows the edges of the screen, not the boxes your game draws: a text that overflows a frame or a speech bubble while staying on screen passes. Check your longest language in the game, or in a test of your own that opens that screen.
- It presses buttons at random. A screen that needs a precise sequence may never be reached: raise `--ticks`, try other seeds, or open that screen at the end of `init` while you test it, then remove the line:

  ```lua
  function SpiffBoySDKHelloGame:init()
      ...
      self:enterTitle()
      self:applyMusic()
      self:enterOver()
  end
  ```

  The robot then starts on the end screen of Hello SpiffBoy.
- It does not play well. In a game of skill, a ship that must dodge or a bat that must fly through gaps, random buttons may never score a single point in 20000 ticks, and `ok` then says nothing of the score, of the speed-up, or of a `persist` placed there: the robot never ran them. When `saves` stays 0 or your game has parts the robot cannot reach, write a test of your own that plays it on purpose ([Writing a test of your own](#writing-a-test-of-your-own)).
- Tunes played through the sequencer do not enter the digest; only direct writes to the chip (`self.chip:write`, `self.chip:loadWave`) do. A tune name that was never registered still crashes the game, and the robot reports it.

## Testing the link cable offline

`tests/spiff_pong/run_link_test.py` plays Spiff-Pong on two consoles joined by a simulated cable, with 1, 6 and 12 ticks of delay, a second player who joins late, a cable pulled in the middle of a match, and one console alone. A linked match passes when both consoles computed the same ball, paddles and score after every tick:

```
cable 6 ticks        ok     frames   2260  most calls  43  delay 9, score 7-3/7-3, longest rally 3, 2167 ticks compared, stalls 0
```

It tests Spiff-Pong only, but `tests/spiff_pong/link_test.lua` is a model for a game of your own on the cable: two runtimes, two ports passing messages with a delay, and a comparison of the two worlds after every tick.

## Writing a test of your own

`tests/lib/test_console.lua` gives a test a console of its own: it starts one cartridge offline on top of SpiffBoy and plays it with the buttons the test chooses, through the same runtime as the game, so every rule applies: the read-only views, the save only on a press, the draw call limit, the coded errors. `tests/run_test.py` runs a test written with it:

```
python tests/run_test.py <SpiffBoy media folder> <mod media folder> <your test>.lua [--lang LANG]
```

`--lang FR` plays the test with the texts of another language, so a translation too long for a screen the robot never reaches shows up. The warnings of the console count as failures, as in the robot: a text off screen, missing art, a text missing in English, a letter the font lacks.

Put your tests in a `tests` folder of the Workshop folder of your mod, next to `Contents`, and end their names with `_test.lua`: `Zomboid/Workshop/MyMod/tests/race_test.lua`. They do not ship to the players, and `run_all.py` runs every one of them.

| Call | Effect |
|---|---|
| `TestConsole.start(folder, seed, save)` | Starts the cartridge of the game folder, such as `"MyMod/Games/SpaceRace"`, with the seed of its generator and the save it reads (`{}` for a new cartridge), and returns the console. |
| `console:press(...)` | Plays one tick with the given buttons pressed, a short press each: `console:press("a")`. |
| `console:hold(ticks, ...)` | Plays the given ticks with the given buttons held down; the first tick counts as their press: `console:hold(30, "up")`. |
| `console:wait(ticks)` | Plays the given ticks without any button. |
| `console:step(held, pressed)` | Plays one tick with a list of buttons held and a list pressed: `console:step({ "left" }, { "a" })`. |
| `console.game` | Your game object. The test may read its fields, such as the score or the screen it shows, to choose what to press next. |
| `console.saves` | A copy of every save the game wrote, in order. |
| `console.crash` | `nil`, or the stage and the message of the error that stopped the game. Once it crashed, the calls above play nothing and return false. |
| `console.most` | The busiest frame so far, in draw calls. |
| `console:screenshot(path)` | Writes the last frame the console drew as a PNG picture, four times the size of the screen, at the given path, a relative path being taken from the folder of the test file, such as `shots/title.png` next to `race_test.lua`, and returns it. Take one after the calls that open the screen you want to see. |
| `TestConsole.check(condition, label)` | Counts a check, and prints `FAIL <label>` when the condition is false. |

The runner prints every failed check and every warning, then `<test> (<language>): <n> checks, <f> failures`, and exits with an error when a check failed, a warning came up or the test stopped on an error. A test that waits for something its game never does loops forever: count the ticks in your loops, as the example below does, and `run_all.py` stops a suite after 900 seconds (`--timeout`). `tests/hello/round_test.lua` is a complete example: it plays rounds of Hello SpiffBoy and checks when the save is written.

A game of skill needs a test that plays like a player. This one flies the bat of a cave game through its gaps by reading where the next gap is, until it scores ten points, then checks that the end screen writes the best score once:

```lua
local check = TestConsole.check
local console = TestConsole.start("CaveMod/Games/CaveFlutter", 7, {})
local game = console.game

console:press("a")
while game.mode == "play" and game.score < 10 and console.ticks < 20000 do
    local gap = game:nextGapCentre()
    if game.batY > gap then
        console:hold(1, "a")
    else
        console:wait(1)
    end
end
check(game.score >= 10, "the autopilot scores ten points")
check(#console.saves == 0, "nothing is written while flying")
```

Your test reads the fields and calls the methods of your own game, here `score`, `batY` and `nextGapCentre`, which only your game knows; the console itself is reached only through `TestConsole`.

## Every test at once: run_all.py

`tests/run_all.py` runs the robot with three seeds, then once in each other language your games have a file for, the text checker, your own tests (`test <name>`, from the `tests` folder of the Workshop folder of your mod) in English and then in each other language (`test <name> FR`), then the tests of the SDK itself, and prints one line per suite. A suite still running after 900 seconds is stopped and fails (`--timeout` changes it):

```
python tests/run_all.py <SpiffBoy media folder> <mod media folder>
```

```
ok    robots seed 12345
ok    robots seed 2718
ok    robots seed 31337
ok    robots AR
ok    robots CA
...
ok    robots UA
ok    check_texts
ok    docs/run_error_codes
ok    dev_menu/run_dev_menu
ok    hello/run_round_test
ok    spiff_pong/run_link_test

all suites passed
```

On your own mod, the `docs`, `dev_menu`, `hello` and `spiff_pong` suites print `skip`: they test parts of the SDK. See [Tools reference](13-tools-reference.md#testsrun_allpy) for the options.

## Testing in the game

### The developer menu

The **SpiffBoy SDK** window ([Getting started](01-getting-started.md#the-developer-menu)) lists every cartridge registered by every loaded mod. If yours is missing, its `Definition.lua` did not run: look in the log. Useful habits:

- **In a console** gives a console with your cartridge inside and a fresh, empty save.
- Two loose cartridges of your game show whether each keeps its own save.
- A link cable and a second player, local or on a server, test the two player mode.

### The log: console.txt

Everything the console writes goes to the log of Project Zomboid, `C:\Users\<you>\Zomboid\console.txt` (`~/Zomboid/console.txt` on Linux and macOS). Search it for `SpiffBoy:`. Every line about your cartridge carries a [code](10-kahlua-and-pitfalls.md#error-codes), such as `[SB-TUNE]`, and ends with `Fix:` and `See:`, the correction and the page of the SDK to read:

| Line | Meaning |
|---|---|
| `SpiffBoy: the cartridge <Id> (class <Class>) crashed in <stage> at tick <n>` | Your game raised an error in `init`, `tick` or `draw`, and the console froze. The next line is the error. |
| `SpiffBoy: [SB-LUA] <message>` | Under a crash line: an error of the Lua of your game. The message of Lua usually names the file and the line. |
| `SpiffBoy: [SB-DRAW-LIMIT] a frame went past 300 draw calls` | Under a crash line: too many draw calls in one frame. |
| `SpiffBoy: [SB-GAME-CLASS] no game class named <name>` | The `game` field of the definition names a class that does not exist: a misspelling, or `Game.lua` failed to load (look for an error above). |
| `SpiffBoy: [SB-TEXT-MISSING] the game <Id> has no text <Key>` | A text key missing from `EN.json`. |
| `SpiffBoy: [SB-ART-MISSING] missing texture <path>` | `context.art` did not find a picture. Check the name and the `art` folder. |
| `SpiffBoy: [SB-GLYPH] pixel font has no glyph for code point <n>` | A character of one of your texts is not in the font. |
| `SpiffBoy: [SB-REG-TUNE] tune <Id>.<name>, voice <voice>, character <n>: ...` | A mistake in the notation of a tune. |
| `SpiffBoy: [SB-TUNE] <Id> has no tune named <name>` | Under a crash line: the game played a tune it never registered. |
| `SpiffBoy: [SB-REG-CARTRIDGE] cartridge <Id> needs ...` | A field of the definition is missing or malformed. |
| `SpiffBoy: [SB-REG-API] cartridge <Id> needs a newer SpiffBoy (api <n>, this SpiffBoy has <m>)` | The `api` of the definition is above the version of the installed SpiffBoy. |
| `SpiffBoy: [SB-REG-DUPLICATE] cartridge <Id> of the mod <Mod> uses an id already registered by the mod <Other>` | Another mod registered a cartridge with the same id: choose another id. |
| `SpiffBoy: [SB-REG-DUPLICATE] cartridge <Id> of the mod <Mod> uses the item <Type> already used by the cartridge <Other> of the mod <OtherMod>` | Another cartridge registered the same item; the same line with `game` names a game class used twice. |
| `SpiffBoy: [SB-REG-TUNES] tunes are registered under the id of a registered cartridge, and no cartridge has the id <Id>` | `SpiffBoy.Tunes.register` got an id no definition registered: a misspelled id, or a definition that failed. |
| `SpiffBoy: [SB-REG-TUNES] tunes are already registered under the id <Id> ...` | `SpiffBoy.Tunes.register` ran twice for the same game. |
| `SpiffBoy: [SB-SAVE-LIMIT] the game <Id> cannot save, the save ...` | Under a crash line: the save broke a limit and `persist` refused it ([Saving](05-saving.md#what-a-save-can-hold)). |
| `SpiffBoy: [SB-TEXTS] the texts of <Id> in <LANG>, file <path> of the mod <Mod>, cannot be read: ...` | Under a crash line: a language file of your game is not valid JSON. Run `check_texts.py`. |
| `SpiffBoy: [SB-REG-TAG] cartridge <Id> of the mod <Mod> has the item <Type> without the tag spiffboy:cartridge: ...` | The item script lacks the cartridge tag ([Dismantling](08-the-cartridge-item.md#dismantling)). |
| `SpiffBoy: [SB-REG-ITEM] cartridge <Id> of the mod <Mod> names the item <Type>, which no item script defines` | The `item` field and the item script disagree. |

An error in a file that loads at start, outside your game, appears as a Lua error with a stack trace: search for `STACK TRACE` and the name of your file.

`print("SpaceRace: score " .. tostring(self.score))` writes your own line in the log while you develop. Prefix your lines with the name of your game to find them, and do not print in every tick: the log grows fast.

Next: [Kahlua and pitfalls](10-kahlua-and-pitfalls.md).
