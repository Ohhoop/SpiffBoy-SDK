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

- Chance comes only from `self.random`, or from a `SpiffBoyRandom` you seed yourself. Never `math.random`, `ZombRand`, `getTimestampMs` or `os.time`.
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

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| The console shows that the game is missing; log: `no game class named` | The `game` field and the global class name differ, or `Game.lua` failed to load. | Use the same name in `derive`, in the global and in the definition. Look for an error above in the log. |
| An error about indexing a nil value in `tick` | A field used before it was set: set on another screen, or misspelled. | Set every field in `init` or in the `open`/`enter` method of the screen. |
| An error about calling a nil value | A misspelled method name, or `self.method()` instead of `self:method()`. | Call the methods of the game with `:`. |
| A variable seems shared by everything | A missing `local`: the variable became a global, shared with every mod. | Always write `local`. Put what must be shared in your namespace table, `MyMod.SpaceRace = {}`. |
| A picture does not show | A wrong file name or `art` folder, or a picture that is not a white mask. | Look for `missing texture` in the log. Draw masks in white. |
| A text shows its key, such as `Play` | The key is missing from `EN.json`. | Run `check_texts.py`. |
| Wrong art or texts: the ones of Hello SpiffBoy | The definition still points at the SDK (`mod`, `art`, `texts`). | Use your own `MyMod.MOD_ID` and folders. `new_cartridge.py` does it for you. |
| The game breaks when a menu cursor goes up from the top | `%` of a negative number. | [Add the count first](#modulo-keeps-the-sign-of-the-left-side). |
| The best score is lost when the console is switched off | `self:persist()` never called. | Call it when the value changes, at a natural moment. |
| The robot shows thousands of saves | `persist` called in every tick. | Persist only when leaving a screen or when something worth keeping changed. |
| An old cartridge breaks the new version | The save holds a value of an older shape. | Check the type of every value read from the save; use defaults. |
| `cannot save, the save ...` | The save broke a limit: a string too long, a key too long, too many entries. | Keep the save small, measure it with `SpiffBoy.SaveData.measure` ([Saving](05-saving.md#watching-the-size)). |
| `uses an id already registered by the mod` | Another mod registered a cartridge with the same id. | Choose an id of your own; prefix the item module and the class with your namespace. |
| `needs a newer SpiffBoy` | The `api` of the definition is above the version of the installed SpiffBoy. | Write `api = 1`, or update SpiffBoy. |
| `a frame went past 300 draw calls` | Too many shapes or letters in one frame. | Count with `screen.calls`, see [the limit](03-screen-and-art.md#the-draw-call-limit). |
| `has no tune named` | A tune played but never registered, or registered under another id. | Keep tune names in constants; register under the id of the cartridge. |
| The game runs faster on a fast computer | Something moves in `draw`, or by elapsed time. | Move it into `tick` and count in ticks. |
| Two consoles on the cable drift apart | `math.random`, `ZombRand` or the clock in the match. | Use a generator seeded with the seed of the match. |
| The mod works in solo, a server refuses the connection | The mod folder is reached through a junction or a symbolic link. | Keep the real files in `Zomboid/Workshop/MyMod`. |

Next: [Publishing](11-publishing.md).
