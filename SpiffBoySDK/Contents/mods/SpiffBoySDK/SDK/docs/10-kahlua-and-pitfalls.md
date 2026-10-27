# 10. Kahlua and pitfalls

Project Zomboid runs Kahlua, a Lua 5.1 written in Java, not the standard Lua interpreter. Everyday code behaves the same, but a few differences break code that works everywhere else, the offline robot included. This page lists them, then the rules of determinism, then the most common mistakes in a cartridge.

## Kahlua differences

### There is no next()

The global function `next` does not exist in the game, so the usual test for an empty table crashes:

```lua
if next(list) == nil then      -- crashes in the game: next is nil
```

Keep a list and test its length, or keep a counter:

```lua
if #list == 0 then
```

For a table with keys, loop and stop at the first one:

```lua
local empty = true
for _ in pairs(map) do
    empty = false
    break
end
```

The robot removes `next` too, so it finds this mistake.

### Modulo keeps the sign of the left side

In standard Lua, `-1 % 10` is `9`. In Kahlua, `%` works like Java: `-1 % 10` is `-1`. Code that wraps a value with `%` breaks as soon as the value goes below zero: a menu cursor, a position on a looping track, an angle.

Add the count before taking the remainder, so the left side is never negative:

```lua
local function wrap(index, step, count)
    return (index - 1 + step + count) % count + 1
end
```

This moves `index` (from 1 to `count`) by `step` (-1 or 1) and wraps it. Spiff-Pong uses it for every menu, and Hello SpiffBoy writes the same formula for its cursor: `(self.selection - 2 + MENU_SIZE) % MENU_SIZE + 1`.

The robot runs standard Lua, so it does not find this one: check every `%` on a value that can be negative.

Dividing a negative number into a whole number needs the same care. `math.floor(-7 / 2)` is `-4`; when you want the result rounded toward zero for both signs, write it, as Spiff-Pong does:

```lua
local function divide(a, b)
    if a < 0 then
        return -math.floor(-a / b)
    end
    return math.floor(a / b)
end
```

### At most 200 local variables per function

Lua 5.1 refuses a function, or a whole file, with more than 200 local variables at the same level: the file stops loading with `main function has more than 200 local variables`. A game file with a long list of `local CONSTANT = ...` at its top reaches it.

- Group constants in tables: `local LAYOUT = { menuY = 54, menuStep = 20, barWidth = 104 }`.
- Split the game by role into several files, as Spiff-Pong does (`Match`, `Brain`, `Link`, `Menus`, `View`...). Each file has its own 200.

### Strings are Java strings

In the game, a string holds UTF-16 units: `string.len`, `string.sub` and `string.byte` count units, and `string.char` accepts codes above 255. In standard Lua, and so in the robot, they count bytes. Two consequences:

- Never measure a text with `string.len` to lay it out: use `screen:textWidth`.
- A link cable message must keep every unit below 256 ([The link cable](07-link-cable.md)). Build messages from `string.char` of values from 0 to 255 and from plain ASCII letters, never from translated texts.

### Files and time

A cartridge reads its files only through the console: its texts through `SpiffBoy.GameTexts`, its art through `context.art`, its save through `self.save`. It counts time in ticks, never with the clock of the computer.

A cartridge also stays out of the world of Project Zomboid: no `getPlayer()`, no character, no inventory, no map. The console isolates the game, as a real handheld knows nothing of the room around it, and the world gives wrong answers anyway: with several players on one computer, `getPlayer()` does not always return the one holding the console.

## Determinism

A game is deterministic when the same seed and the same buttons always give the same game. The robot relies on it to compare two runs with `--compare`, and two consoles on the link cable rely on it to compute the same match. The rules:

- Chance comes only from `self.random`, or from a `SpiffBoyRandom` you seed yourself. Never `math.random`, `ZombRand`, `getTimestampMs`, `os.time`, `os.clock` or `os.date`; the robot stops a game that calls them (`SB-REPEAT`).
- Time is counted in ticks, never in milliseconds.
- `draw` never changes the state. It can run any number of times between two ticks.
- No `pairs` where the order matters. The order of `pairs` is not fixed; loop over lists with `ipairs` or an index.
- Whole numbers in a match played on the cable. Spiff-Pong counts positions in sub pixels, 16 per pixel, so the ball can move 1.5 pixels a tick as 24 sub pixels and no fraction is ever rounded differently on the two consoles. Divide negative values as shown [above](#modulo-keeps-the-sign-of-the-left-side).
- A match reads nothing from outside. Only its own state and the inputs it is given: not the save, not the options of this console (the leader sends its options in the start message), not the screen.
- Keep drawing and sound out of the match. Spiff-Pong's match records events (`paddle`, `wall`, `point`) and the game turns them into sound effects, so sound and drawing can differ between consoles without consequence.

## Performance

A cartridge runs its `tick` 60 times a second, inside the game.

- Load art in `init`, and text functions and modules at the top of the file, never in `draw`.
- Do not create tables in every tick or frame: reuse them, or use constants such as `local NEUTRAL = { up = false, down = false }`.
- Keep the draw calls low: every one is a drawing order for the game, and the console stops at 300 ([Screen and art](03-screen-and-art.md#the-draw-call-limit)).
- Avoid `table.remove(list, 1)` on long lists every tick: it moves every element. Keep the index of the first element instead.

## Error codes

Each rule of the console has a code. When your cartridge breaks one, the line in `console.txt` gives the code, what the console refused, how to fix it and the page of the SDK to read. A crash comes with a first line that names the cartridge, its class, the stage (`init`, `tick` or `draw`) and the tick:

```
SpiffBoy: the cartridge SpaceRace (class MyModSpaceRaceGame) crashed in tick at tick 1234
SpiffBoy: [SB-SAVE-PRESS] the game SpaceRace tried to save without a button press, and nothing was written. Fix: save on the press that answers it: the end screen confirmed, a SAVE entry, the options left. See: SDK docs/05-saving.md, When to save.
```

An error of your own code, such as indexing a nil value, or an `error` your game raises, comes under the code `SB-LUA` with the message of Lua. A line with a code and no crash line above it is a warning: the game keeps running.

| Code | Raised when | Effect |
|---|---|---|
| `SB-LUA` | The Lua of the game fails, or the game calls `error`. | The game crashes. |
| `SB-SAVE-PRESS` | `self:persist()` runs outside the tick of a press: in `init`, in `draw`, on a timer. | The game crashes; nothing is written. |
| `SB-SAVE-LIMIT` | The save breaks a limit: a string or a key too long, too many entries, too deep. | The game crashes; nothing is written. |
| `SB-SAVE-TABLE` | `SpiffBoy.SaveData.measure` gets something that is not a table. | The game crashes. |
| `SB-DRAW-LIMIT` | A frame goes past 300 draw calls. | The game crashes. |
| `SB-SHADE` | A drawing method gets a shade outside 1 to 4. | The game crashes. |
| `SB-TUNE` | `play` or `effect` names a tune the cartridge did not register. | The game crashes. |
| `SB-CHIP-REGISTER` | `chip:write` gets a number that is no sound register. | The game crashes. |
| `SB-CHIP-VALUE` | `chip:write` gets a value that is not a whole number from 0 to 255. | The game crashes. |
| `SB-CHIP-WAVE` | `chip:loadWave` gets a name no wave table has. | The game crashes. |
| `SB-LINK-MESSAGE` | `link:send` gets an empty text, a text over 16 bytes, or no text. | The game crashes. |
| `SB-REPEAT` | In the robot and in `tests/run_test.py` only: the game calls `math.random`, `math.randomseed`, `ZombRand`, `os.time`, `os.clock`, `os.date` or `getTimestampMs`. | The game crashes in the test; in Project Zomboid the call works but the game cannot be repeated. |
| `SB-SEED` | `SpiffBoyRandom.new` or `reseed` gets something that is not a number. | The game crashes. |
| `SB-HIDDEN` | The game reads a member that the screen, the context, an input, its `held` or `pressed`, the sequencer, the chip or the link port does not give: a misspelling, or a member the console keeps for itself. | The game crashes. |
| `SB-READONLY` | The game writes a field on one of these objects. | The game crashes. |
| `SB-ART-MOD` | `art` runs for a definition whose `mod` is not loaded. | The game crashes. |
| `SB-TEXTS` | A language file is not valid JSON, holds no object or has no `UI` section. | The game crashes. |
| `SB-TEXTS-ID` | A text function made for an id no cartridge registered is called. | The game crashes. |
| `SB-REG-CARTRIDGE` | A field of the definition is missing or malformed. | The cartridge is not registered. |
| `SB-REG-API` | The `api` of the definition is missing, or above the version of the installed SpiffBoy. | The cartridge is not registered. |
| `SB-REG-DUPLICATE` | Another cartridge already uses the id, the item or the game class. | The cartridge is not registered. |
| `SB-REG-TUNES` | `SpiffBoy.Tunes.register` gets an id no cartridge has, runs twice for one id, or gets a tune name too long. | No tune of the call is registered. |
| `SB-REG-TUNE` | A tune does not compile: a fault in its notation, an echo, its voices or its loop. Also a looping tune whose voices do not all last as long as the tune. | No tune of the call is registered; for the voice lengths, a warning only: the voices fall out of step at each loop. |
| `SB-REG-ITEM` | No item script defines the `item` of the definition. | Warning. |
| `SB-REG-TAG` | The item lacks the tag `spiffboy:cartridge`. | Warning: the dismantling recipe does not take it. |
| `SB-GAME-CLASS` | No global class has the name of the `game` field. | Warning: the console shows that the game is missing. |
| `SB-TEXT-MISSING` | A text key is missing from `EN.json`. | Warning: the key is shown. |
| `SB-ART-MISSING` | `art` finds no file of that name. | Warning: `art` returns nil. |
| `SB-GLYPH` | A text holds a character the pixel font lacks. | Warning: the character is left out. |

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| The console shows that the game is missing; log: `no game class named` | The `game` field and the global class name differ, or `Game.lua` failed to load. | Use the same name in `derive`, in the global and in the definition. Look for an error above in the log. |
| An error about indexing a nil value in `tick` | A field used before it was set: set on another screen, or misspelled. | Set every field in `init` or in the `open`/`enter` method of the screen. |
| An error about calling a nil value | A misspelled method name, or `self.method()` instead of `self:method()`. | Call the methods of the game with `:`. |
| `attempt to call global 'next' (a nil value)` | `next` does not exist in the game. | Use `pairs` ([There is no next()](#there-is-no-next)). |
| `attempt to call global 'getPlayer' (a nil value)`, or any other function of Project Zomboid | A cartridge stays out of the world of Project Zomboid: the console gives a game no character, inventory or map. | Keep everything the game needs in its own fields and its save ([Kahlua differences](#kahlua-differences)). |
| A variable seems shared by everything | A missing `local`: the variable became a global, shared with every mod. | Always write `local`. Put what must be shared in your namespace table, `MyMod.SpaceRace = {}`. |
| A picture does not show | A wrong file name or `art` folder, or a picture that is not a white mask. | Look for `missing texture` in the log. Draw masks in white. |
| A text shows its key, such as `Play` | The key is missing from `EN.json`. | Run `check_texts.py`. |
| Wrong art or texts: the ones of Hello SpiffBoy | The definition still points at the SDK (`mod`, `art`, `texts`). | Use your own `MyMod.MOD_ID` and folders. `new_cartridge.py` does it for you. |
| The game breaks when a menu cursor goes up from the top | `%` of a negative number. | [Add the count first](#modulo-keeps-the-sign-of-the-left-side). |
| The best score is lost when the console is switched off | `self:persist()` never called. | Call it at the end of the game, on the press that confirms the end screen ([When to save](05-saving.md#when-to-save)). |
| An old cartridge breaks the new version | The save holds a value of an older shape. | Check the type of every value read from the save; use defaults. |
| The game runs faster on a fast computer | Something moves in `draw`, or by elapsed time. | Move it into `tick` and count in ticks. The robot warns when `draw` changes a field of the game that holds a number, a text or a boolean. |
| Two consoles on the cable drift apart | `math.random`, `ZombRand` or the clock in the match. | Use a generator seeded with the seed of the match. |
| The mod works in solo, a server refuses the connection | The mod folder is reached through a junction or a symbolic link. | Keep the real files in `Zomboid/Workshop/MyMod`. |

Next: [Publishing](11-publishing.md).
