# 5. Saving

The save of a game is stored on the cartridge item. It stays when the console is switched off and when the game session ends, and it follows the cartridge into another console. Two cartridges of the same game are two items with two saves.

## self.save and persist

When the game starts, the base class loads the save of the cartridge into `self.save`, a plain Lua table, empty on a new cartridge. Read and write it like any table, then call `self:persist()` to write it on the cartridge.

Nothing is written until you call `persist`. When the console is switched off, the game stops without saving: the changes since the last `persist` are lost.

### When to save

A cartridge saves like the games of its time: there is no saving on its own, no saving while the player plays. It writes its save at three kinds of moments, each one the answer to a press of the player:

- the end of a game, for its score: the press that confirms the end screen, or the last letter of the initials;
- a save the player asks for: a SAVE entry in a menu, as in an adventure;
- the options, once, when the player leaves the options screen after changing something.

Never when the player leaves a screen in the middle of a game, never when the console is switched off, never in every tick. Some games of the time saved nothing at all, or gave the player a code to write down; those are choices too.

The console holds you to it: `persist` works only during the tick in which the player pressed one of the seven buttons of the console, A, B, Start or a direction, even one your game does not read: a press of any of them lets that tick save. Called anywhere else, in `init`, on a timer, when a match is decided by the clock or by the other console, it raises an error and the game stops:

```
SpiffBoy: [SB-SAVE-PRESS] the game SpaceRace tried to save without a button press, and nothing was written. Fix: save on the press that answers it: the end screen confirmed, a SAVE entry, the options left. See: SDK docs/05-saving.md, When to save.
```

A save on every press during play is no error for the console, since each one follows a press, but it rewrites the same save again and again: the robot marks the game `WARN` past 5 saves within ten seconds that change nothing in the save. Saves that change something, such as the options left after a change, never count. A save on a timer can pass while the player happens to press a direction at that tick, and fail on the next game. The robot catches it: it presses buttons at random and also pauses one to five seconds without any button, so a game that saves on its own meets ticks without a press. The robot adds where the call came from, `persist called at lua/client/<Ns>/Games/<Id>/Game.lua:<line>`, before `. Fix:`.

`persist` rewrites the item; in multiplayer it sends the save to the server, which writes it. Write everything that changed in one `persist`.

Hello SpiffBoy saves at the end of a round. Nothing is written during the round nor when the player gives it up with Start; the end screen waits for A or Start, and that press writes the best count and the music option together, only when one of them changed:

```lua
function SpiffBoySDKHelloGame:tickOver(input)
    self.overTicks = self.overTicks + 1
    local pressed = input.pressed
    if pressed.a or pressed.start then
        self.sequencer:effect(Music.SELECT)
        self:saveRound()
        self:enterTitle()
    end
end

function SpiffBoySDKHelloGame:saveRound()
    local changed = false
    if self.best ~= self.save.best then
        self.save.best = self.best
        changed = true
    end
    if self.musicOn ~= readMusic(self.save) then
        self.save.options = { music = self.musicOn }
        changed = true
    end
    if changed then
        self:persist()
    end
end
```

The music option has no options screen in Hello SpiffBoy: B or the title menu switch it in the game, and it reaches the cartridge with the next end of a round.

## What a save can hold

A save must fit these limits:

| Allowed | Limit |
|---|---|
| Keys | strings of at most 32 characters, or whole numbers |
| Numbers | finite numbers (not infinity, not NaN) |
| Strings | at most 128 characters |
| Booleans | `true`, `false` |
| Tables | nested up to 6 levels, the save itself counting as the first |
| Size | at most 512 entries in all, counting the entries of every nested table |

Nothing else is allowed: no function, no texture, no other kind of value.

`persist` checks the save before writing it. A save that breaks a limit is not written at all: `persist` raises an error that names the game, the first limit broken and its place in the save, and the game stops as on any other error ([Crashes](02-how-a-cartridge-works.md#crashes)). The log then reads, for example:

```
SpiffBoy: [SB-SAVE-LIMIT] the game SpaceRace cannot save, the save at records.names.1 holds a string of 140 characters, at most 128 are kept, and nothing was written. Fix: keep the save within the limits and measure it with SpiffBoy.SaveData.measure. See: SDK docs/05-saving.md, What a save can hold.
```

The server checks every save it receives the same way and refuses a save that breaks a limit as a whole. The [robot](09-testing.md#the-robot) runs the same check in `persist`, so a save that breaks a limit shows there as a crash, as soon as the robot plays far enough to write it.

Loading is more forgiving, so an old cartridge never stops your game: when the game starts, the console cleans the save it reads, cutting a string longer than 128 characters, dropping a key that is too long with its value, a value of another kind, and everything past the 512th entry.

### Watching the size

`SpiffBoy.SaveData.measure(save)` returns the number of entries of a save, counted as the limit of 512 counts them. `SpiffBoy.SaveData.check(save)` returns the message of the first limit the save breaks, or nil when it fits. Both work on any table. A game that keeps a growing list, such as the times of every race, can measure the save before it persists and drop its oldest entries while it holds too many:

```lua
local SAVE_BUDGET = 400

function MyModSpaceRaceGame:keepTime(time)
    if type(self.save.times) ~= "table" then
        self.save.times = {}
    end
    local times = self.save.times
    times[#times + 1] = time
    while #times > 0 and SpiffBoy.SaveData.measure(self.save) > SAVE_BUDGET do
        table.remove(times, 1)
    end
    self:persist()
end
```

Keep the save to a few numbers, a few short texts and a list or two, and it stays far below the limits.

## Never trust a save

A save can come from an older version of your game, or from a cartridge that was never played. Check the type of every value you read, and use a default when it is not what you expect. Hello SpiffBoy reads its best count like this:

```lua
local function readBest(save)
    local best = save.best
    if type(best) ~= "number" or best < 0 then
        return 0
    end
    return math.min(math.floor(best), MAX_COUNT)
end
```

and a setting that is on for a new cartridge, kept in the entry of the options, like this:

```lua
local function readMusic(save)
    local options = save.options
    return type(options) ~= "table" or options.music ~= false
end
```

Spiff-Pong keeps each kind of saved data in its own module, with a `read(save)` that returns clean values and a `write(save, values)` that puts them back; the rest of the game never touches `self.save` directly. Its options:

```lua
function Options.read(save)
    local options = { music = Options.DEFAULTS.music, speed = Options.DEFAULTS.speed, points = Options.DEFAULTS.points }
    local saved = save.options
    if type(saved) ~= "table" then
        return options
    end
    if type(saved.music) == "boolean" then
        options.music = saved.music
    end
    if isIndex(saved.speed, #Match.SPEEDS) then
        options.speed = saved.speed
    end
    ...
```

## Pattern: best scores with initials

Spiff-Pong keeps the five longest rallies with the three initials of each player. Each entry is stored as one short text, `"ABC:12"`, which keeps the save small and easy to check:

```lua
Records.SIZE = 5
local ENTRY_PATTERN = "^([A-Z0-9][A-Z0-9][A-Z0-9]):(%d+)$"
local MAX_DIGITS = 6

function Records.read(save)
    local records = { rallies = {}, wins = 0, losses = 0 }
    local saved = save.records
    if type(saved) ~= "table" then
        return records
    end
    records.wins = readCount(saved.wins)
    records.losses = readCount(saved.losses)
    if type(saved.rallies) == "table" then
        for i = 1, Records.SIZE do
            local entry = saved.rallies[i]
            if type(entry) == "string" then
                local initials, digits = string.match(entry, ENTRY_PATTERN)
                if initials and string.len(digits) <= MAX_DIGITS then
                    records.rallies[#records.rallies + 1] = { initials = initials, rally = tonumber(digits) }
                end
            end
        end
    end
    return records
end

function Records.write(save, records)
    local rallies = {}
    for i = 1, #records.rallies do
        local entry = records.rallies[i]
        rallies[i] = entry.initials .. ":" .. tostring(entry.rally)
    end
    save.records = { rallies = rallies, wins = records.wins, losses = records.losses }
end
```

Inside the game the records are a clean list of `{ initials, rally }`, best first; only `read` and `write` know the text form.

`Records.rankOf(records, rally)` walks the list from the best entry and returns the first rank the new rally beats, the next free rank while the table holds fewer than five entries, or nil. `Records.insert` puts the entry at that rank with `table.insert` and drops what falls past the fifth place with `table.remove`.

The flow in the game:

1. At the end of the match, compute the rank. Nil means the score does not enter the table.
2. When it enters, open an initials screen: up and down change the current letter among `ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789`, A moves to the next letter, B goes back one.
3. After the third letter, insert the entry, write the records and persist once.
4. Show the table with the new line blinking.

`Results.lua` of Spiff-Pong does exactly this ([walkthrough](12-spiff-pong-walkthrough.md#resultslua-results-and-initials)). With one table per mode or per level, the idea is the same; count the entries against the limit of 512: three tables of ten texts are 30 entries.

## Pattern: options

Options (music on or off, difficulty, speed) belong in the save, in an entry of their own, `self.save.options`, apart from the scores and the progress, so they are set once per cartridge. Read them in `init`, change them on the options screen, and write and persist once, when the player leaves the screen with a button, only if something changed:

```lua
if pressed.a or pressed.b or pressed.start then
    if self.optionsChanged then
        Options.write(self.save, self.options)
        self:persist()
    end
    self:effect(Music.BACK)
    self:openTitle()
end
```

## Changing the save between versions

Cartridges already in the world keep the save of the version that wrote it:

- New fields are free to add: old saves do not have them, and your reading code gives the default.
- Do not change the meaning of an existing field. Store new data under a new key.
- If the shape changes a lot, store a version number, `save.version = 2`, and convert old saves when you read them.

Next: [Texts and translations](06-texts-and-translations.md).
