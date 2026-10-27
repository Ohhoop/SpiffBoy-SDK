# 13. Tools reference

Every tool is a Python 3 script. The tools need Pillow and numpy, the tests lupa (`pip install pillow numpy lupa`). Each one exits with code 0 on success and 1 on a problem, so they can be chained in a script.

## Folders

Every command on this page runs from the `SDK` folder of the SpiffBoy SDK mod, so `tools/...` and `tests/...` name the scripts of the kit. The [README](../README.md#where-the-kit-is) shows where Steam puts that folder. The paths in the examples:

- **SpiffBoy media folder**: the media folder of the SpiffBoy mod, `<Steam>/steamapps/workshop/content/108600/<SpiffBoy id>/mods/SpiffBoy/42/media`, where `<SpiffBoy id>` is the number at the end of the address of the Workshop page of SpiffBoy.
- **SDK media folder**: the media folder of the SpiffBoy SDK mod, `../42/media` from the `SDK` folder.
- **Mod media folder**: the media folder of your mod, `C:/Users/<you>/Zomboid/Workshop/MyMod/Contents/mods/MyMod/42/media`.

| Tool | Does |
|---|---|
| [tools/new_cartridge.py](#new_cartridgepy) | Creates a new cartridge in your mod from Hello SpiffBoy. |
| [tools/shade_layers.py](#shade_layerspy) | Turns pictures into a layered sheet and reports the draw calls of each cell. |
| [tools/cartridge_label.py](#cartridge_labelpy) | Puts a label on the blank cartridge: the 3D model texture, the inventory icon and the picture of the mod. |
| [tools/check_texts.py](#check_textspy) | Checks the text files of every game and the keys the code asks for. |
| [tests/robots/run_robots.py](#testsrobotsrun_robotspy) | Plays every cartridge offline with random buttons. |
| [tests/run_test.py](#testsrun_testpy) | Runs a test of your own, written with `tests/lib/test_console.lua`. |
| [tests/spiff_pong/run_link_test.py](#testsspiff_pongrun_link_testpy) | Plays Spiff-Pong on two simulated consoles joined by a cable. |
| [tests/dev_menu/run_dev_menu.py](#testsdev_menurun_dev_menupy) | Checks the developer menu of the SDK. |
| [tests/hello/run_round_test.py](#testshellorun_round_testpy) | Plays whole rounds of Hello SpiffBoy and checks when it saves. |
| [tests/docs/run_error_codes.py](#testsdocsrun_error_codespy) | Checks the error codes of SpiffBoy against the documentation of the SDK. |
| [tests/run_all.py](#testsrun_allpy) | Runs every test suite. |

## new_cartridge.py

Creates a new cartridge in a mod by copying Hello SpiffBoy and renaming every name of the example. [Getting started](01-getting-started.md#copy-the-example-with-new_cartridgepy) shows a full run.

```
python tools/new_cartridge.py --sdk <SDK media folder> --mod <mod media folder> --namespace <Ns> --module <Module> --id <Id> --title "<Title>" --mod-id <mod id>
```

| Option | Meaning |
|---|---|
| `--sdk` | The media folder of the SDK, where Hello SpiffBoy is read. |
| `--mod` | The media folder of your mod. It must exist. |
| `--namespace` | The folder name of your mod under `lua`, `ui`, `scripts` and `textures`, and its global Lua table. Letters and digits, starting with a letter. |
| `--module` | The script module of the cartridge item. Letters and digits, starting with a letter. |
| `--id` | The id of the new game. Letters and digits, starting with a letter. |
| `--title` | The title of the game: one line without quotes, backslashes or tabs. |
| `--mod-id` | The `id=` of your `mod.info`: letters, digits, spaces, dots, dashes and underscores. |

It copies the files listed in [Getting started](01-getting-started.md#or-copy-the-example-by-hand), `Core.lua` aside, under the names of your cartridge. Of the texts of the game it copies `EN.json` only: the console shows the English texts in every language that has no file. It leaves out the comments that point to the exercises of Hello SpiffBoy. The definition of your cartridge gets the loot weight 2 of the cartridges of SpiffBoy, where the example has 0, and its first comment describes your game instead of the example. The header of `Game.lua` no longer lists what Hello SpiffBoy does: it says the file starts as a copy of the example, and keeps the explanation of how the console runs a game. It writes `lua/shared/Translate/EN/ItemName.json` with the English name of the item when your mod has none, and otherwise prints the line to add to it. It writes `lua/shared/<Ns>/Core.lua`, which defines the table `<Ns>` and `<Ns>.MOD_ID`, when your mod has none. An existing `Core.lua` must already define `<Ns>.MOD_ID`.

In the copied `.lua`, `.json` and `.txt` files it replaces, in this order: the game class `SpiffBoySDKHelloGame` by `<Ns><Id>Game`, the item `SpiffBoySDK.Cartridge_HelloSpiffBoy` by `<Module>.Cartridge_<Id>`, the icon `SpiffBoySDK_Cartridge_HelloSpiffBoy` by `<Module>_Cartridge_<Id>`, `module SpiffBoySDK` by `module <Module>`, the title `Hello SpiffBoy` and `HELLO SPIFFBOY`, the id `HelloSpiffBoy`, and the namespace `SpiffBoySDK`.

It writes nothing when a file to create already exists, when a name of the example is left in a copied file after renaming, or when the definition of the example no longer registers the names it expects; it prints the problems instead. It never writes `mod.info`, and never changes an existing `ItemName.json`.

## shade_layers.py

Turns pictures drawn for the screen into a layered sheet for `screen:layers`, and reports the draw calls each cell costs. [Screen and art](03-screen-and-art.md#making-art-with-shade_layerspy) shows the workflow.

```
python tools/shade_layers.py <picture> [<picture> ...] -o <sheet.png> [--cell WxH] [--grey]
```

| Option | Meaning |
|---|---|
| `<picture>` | One or more PNG pictures. Several pictures are laid side by side in the order given. |
| `-o`, `--output` | The layered sheet to write. Its folder is created if needed. |
| `--cell WxH` | Cuts each picture into cells of W by H pixels, left to right then top to bottom. Without it, each picture is one cell. |
| `--grey` | The pictures are in greys instead of the four exact shades: 0 to 63 is shade 1, 64 to 127 shade 2, 128 to 191 shade 3, 192 to 255 shade 4. A coloured pixel is refused. |

Without `--grey`, every opaque pixel must be one of the four shades exactly: RGB 28,36,32 / 72,86,78 / 112,128,118 / 156,168,160. Every pixel must be fully transparent or fully opaque, and all cells must share one height. The tool refuses anything else and names the first faulty pixel:

```
shade_layers: hero.png: 3 pixels are not one of the four shades, the first at 5,2 is (30, 36, 32)
```

The report gives one line per cell, then the size of the sheet; [Screen and art](03-screen-and-art.md#start-from-the-example-drawing) shows one. `sx` is the value to give `screen:layers` for that cell, and the shades list is the smallest `shades` argument that draws the whole cell.

Examples:

```
python tools/shade_layers.py hero.png -o ".../media/ui/MyMod/Games/MyGame/hero.png"
python tools/shade_layers.py tiles_grey.png --grey --cell 8x8 -o ".../tiles.png"
```

## cartridge_label.py

Puts the label of a game on the blank cartridge that comes with the tool, in `tools/cartridge/`. [The cartridge item](08-the-cartridge-item.md#the-label-the-icon-and-the-3d-model) shows where the files go.

```
python tools/cartridge_label.py <label.png> <texture.png> <icon.png> [<poster.png>]
```

| Argument | Meaning |
|---|---|
| `<label.png>` | The label of the game, 388x212 or any picture in the same proportions. A picture in other proportions would be stretched: the tool refuses it, names its size and writes nothing. |
| `<texture.png>` | The texture of the 3D model to write, `media/textures/<Ns>/<Ns>Cartridge_<Id>.png`. |
| `<icon.png>` | The 64x64 inventory icon to write, `media/textures/Item_<Module>_Cartridge_<Id>.png`. |
| `<poster.png>` | Optional: the picture of the mod to write, the cartridge wearing the label on a transparent square of 256x256. Copy it as `poster.png` next to each `mod.info` of your mod and as `preview.png` for its Workshop page. |

## check_texts.py

Checks the texts of every cartridge of a mod: the language files of each game and the keys its code asks for. [Texts and translations](06-texts-and-translations.md#checking-your-texts) shows the output.

```
python tools/check_texts.py <mod media folder> [--games A,B]
```

| Option | Meaning |
|---|---|
| `<mod media folder>` | The media folder of your mod. |
| `--games A,B` | Only these game ids. An unknown id is an error. |

For every game folder `lua/shared/<Ns>/Games/<Id>/` with a `Definition.lua`, it reads `Translate/<LANG>.json` and checks that:

- every file is valid JSON in UTF-8, named in capitals like a language code (`EN`, `FR`, `PTBR`, `ES_MX`), an object of sections holding only texts, with no key repeated and every key made of letters, digits and underscores, starting with a letter;
- `EN.json` exists and has a `"UI"` section;
- every other language holds exactly the sections and keys of `EN.json`; missing and extra keys are listed;
- the Lua files call `SpiffBoy.GameTexts.of` with the id of the game, and no other id; a game whose `EN.json` holds keys but whose files never call it fails;
- no text with letters is drawn straight from the code, such as `screen:textCentre("GAME OVER", ...)`, or through a constant of the same file, `local OVER = "GAME OVER"` then `screen:textCentre(OVER, ...)`, or a field of a table of constants, `local LABELS = { over = "GAME OVER" }` then `screen:textCentre(LABELS.over, ...)`: it goes in `EN.json`;
- `lua/shared/Translate/EN/ItemName.json` gives a name to the `item` of the definition;
- every key the Lua files of the game ask for in quotes, `gameText("Key")`, exists in the `"UI"` section of `EN.json`;
- every prefix asked for, `gameText("Item_" .. id)`, starts at least one key.

The Lua scan reads the files of `lua/client`, `lua/shared` and `lua/server` under `<Ns>/Games/<Id>/` without running them. It follows the names given to `SpiffBoy.GameTexts.of("<Id>")` and the variables copied from them. Keys computed at run time cannot be checked and are counted. A game with problems shows `FAIL` and one indented line per problem.

## tests/robots/run_robots.py

Plays every cartridge of a mod offline on top of SpiffBoy, pressing seeded random buttons with pauses of one to five seconds, and reports for each game its crash, its busiest frame in draw calls, its saves and a digest of its draw calls and chip writes. [Testing](09-testing.md#the-robot) explains the output and what the robot does not see.

```
python tests/robots/run_robots.py <SpiffBoy media folder> <mod media folder> [--games A,B] [--ticks N] [--seed N] [--lang LANG] [--json file] [--compare file]
```

| Option | Default | Meaning |
|---|---|---|
| `--games A,B` | every game | Only these game ids. |
| `--ticks N` | 20000 | Ticks played per game. |
| `--seed N` | 12345 | Seed of the game and of the buttons. Another seed plays another session. |
| `--lang LANG` | EN | Language the games read their texts in, such as FR or JP. |
| `--json file` | | Writes the results, to compare later. |
| `--compare file` | | Fails on any game whose digest or frame count differs from the file. |

It plays every game with a `lua/shared/<Ns>/Games/<Id>/Definition.lua` and loads `lua/client/<Ns>/Games/<Id>/Game.lua`. It exits with 1 when a game crashed (`CRASH`: a file that fails to load, a missing game class, any error such as more than 300 draw calls), warned (`WARN`: a missing picture, a picture named with another letter case than its file, a text missing in English, a text drawn off screen, an item script missing or without the cartridge tag, a `derive` name that differs from the global class name, a `require` of the mod that finds no file or finds it only in another letter case, a letter the pixel font lacks, a looping tune whose voices differ in length, more than 5 saves within ten seconds that change nothing, a picture loaded in `draw` or with `getTexture`, a field of the game changed by `draw`, a global variable without the namespace of the mod), or differs from the reference. A call from the game to `math.random`, `math.randomseed`, `ZombRand`, `os.time`, `os.clock`, `os.date` or `getTimestampMs` stops it with `SB-REPEAT`. A folder without `mod.info` next to it, or holding no cartridge, such as the `42` folder instead of `42/media`, is refused with a message. A game that never saved gets a `note:` line: check its saves in a test of your own.

## tests/run_test.py

Runs a test of your own, written in Lua with `tests/lib/test_console.lua`, on a cartridge of a mod. [Writing a test of your own](09-testing.md#writing-a-test-of-your-own) lists the calls and gives an example.

```
python tests/run_test.py <SpiffBoy media folder> <mod media folder> <test.lua> [--lang LANG]
```

| Option | Default | Meaning |
|---|---|---|
| `--lang LANG` | EN | Language the game reads its texts in, such as FR. |

It prints every failed check and every warning, then the number of checks and failures, and exits with 1 when a check failed, a warning came up or the test stopped on an error. The robot's rules apply to the game: `SB-REPEAT`, the letter case of pictures, the warnings of the console, a text drawn off screen. `console:screenshot(path)` writes a PNG picture of the last frame.

## tests/spiff_pong/run_link_test.py

Plays Spiff-Pong on two consoles joined by a simulated link cable, offline, and checks that both consoles stay in step.

```
python tests/spiff_pong/run_link_test.py <SpiffBoy media folder> <SDK media folder>
```

The scenarios: cables of 1, 6 and 12 ticks of delay through a whole match, a second player who joins late, a cable pulled in the middle of a match, and one console alone through a match, its initials and its best scores. A linked match passes when both consoles computed the same ball, paddles and score after every tick, their checksums agreed, no match waited more than half a second for the cable, the port never refused a message, and every frame stayed under 300 draw calls. It prints one line per scenario and a summary.

It tests Spiff-Pong only; `tests/spiff_pong/link_test.lua` is a model for a test of your own game.

## tests/dev_menu/run_dev_menu.py

Checks the developer menu of the SDK offline: the items it gives, and the requests it accepts or refuses, in solo and in multiplayer. It tests the SDK only.

```
python tests/dev_menu/run_dev_menu.py <SpiffBoy media folder> <SDK media folder>
```

## tests/hello/run_round_test.py

Plays rounds of Hello SpiffBoy offline with `tests/lib/test_console.lua` and checks when the game writes its save: never during a round nor when a round is given up, once when the end of a round is confirmed with a button, and only what changed. It tests Hello SpiffBoy only; its `round_test.lua` is a model for a test of your own, run with [tests/run_test.py](#testsrun_testpy).

```
python tests/hello/run_round_test.py <SpiffBoy media folder> <SDK media folder>
```

## tests/docs/run_error_codes.py

Checks the [error codes](10-kahlua-and-pitfalls.md#error-codes) of SpiffBoy against the documentation of the SDK: every code points to a page and a section that exist, and the table of the codes lists every code and no other. It tests the documentation of the SDK only.

```
python tests/docs/run_error_codes.py <SpiffBoy media folder> <SDK media folder>
```

## tests/run_all.py

Runs every offline test suite, each in its own process, and prints one `ok`, `FAIL` or `skip` line per suite.

```
python tests/run_all.py <SpiffBoy media folder> <mod media folder> [--ticks N] [--timeout S] [--verbose]
```

| Option | Default | Meaning |
|---|---|---|
| `--ticks N` | 20000 | Ticks each robot plays per game. |
| `--timeout S` | 900 | Seconds a suite may run before it is stopped and fails. |
| `--verbose` | off | Prints the output of every suite; otherwise only the output of the failed suites, after the summary. |

The suites are the robots, once per seed (12345, 2718 and 31337), then once with the seed 12345 in each language other than English that a game of the mod has a text file for (`robots FR`, ...), then `tools/check_texts.py`, then every test of your own (`test <name>`), each file ending in `_test.lua` in the `tests` folder of the Workshop folder of the mod, next to `Contents`, run with `tests/run_test.py`, then the tests of the SDK itself, `docs`, `dev_menu`, `hello` and `spiff_pong`. A test of the SDK runs only on a mod holding the folder it tests and prints `skip` on any other mod, so on your own mod the robots and the text checker do the work. Before anything, it checks that both folders have a `mod.info` next to them.

Back to the [README](../README.md).
