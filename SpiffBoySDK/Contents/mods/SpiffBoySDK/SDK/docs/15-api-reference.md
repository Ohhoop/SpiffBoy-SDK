# 15. API reference

This page lists every object a cartridge uses, one section per object. Each method is one row: the call, what it does, what it returns, and what happens at the edges. The pages linked from each section explain the topic in depth.

An error raised inside `init`, `tick` or `draw` crashes the game ([Crashes](02-how-a-cartridge-works.md#crashes)). An error raised while a file loads, as a registration does, stops that file.

## The game class

A game class is derived from `SpiffBoyGameBase` (`require "SpiffBoy/Core/GameBase"`). [How a cartridge works](02-how-a-cartridge-works.md#the-game-class) explains the class and its life.

| Call | Does | Returns | Edges |
|---|---|---|---|
| `SpiffBoyGameBase:derive(name)` | Creates a class that inherits every method of the base class and sets its `Type` field to `name`. | The new class. | `name` is not checked. The crash report prints it: `SpiffBoy: the cartridge <id> (class <name>) crashed in <stage> at tick <tick>`. |
| `Class:new(runtime, context)` | Called by the console when the game starts: sets the fields below, then calls `init`. | The game. | Do not override it. An error in `new` or `init` crashes the game at the stage `init`. |
| `self:init()` | Override it. Called once, by `new`, after the fields are set. | Nothing. | The base version does nothing. |
| `self:tick(inputs, tick)` | Override it. Called at 60 ticks per second. `inputs` is the list of [input states](#the-input-state). `tick` is 1 on the first call and grows by one on each call. | Nothing. | Not called while Project Zomboid is paused, while the console is frozen, or after a crash. |
| `self:draw(screen)` | Override it. Called each time the window paints a frame. `screen` is the same object as `self.screen`. | Nothing. | It can run several times with no tick in between, and not at all after a crash. |
| `self:persist()` | Writes `self.save` on the cartridge, with the battery charge and the volume, on the console; in multiplayer it sends them to the server. | Nothing. | Raises `SpiffBoy: [SB-SAVE-PRESS] the game <id> tried to save without a button press, and nothing was written` outside the tick in which `inputs[1]` has a button or a direction pressed (`pressed`, not `held`): in `init`, in `draw`, in a tick with no press. Raises `SpiffBoy: [SB-SAVE-LIMIT] the game <id> cannot save, <problem>, and nothing was written` when the save breaks a limit, `<problem>` being the message of [`SpiffBoy.SaveData.check`](#spiffboysavedata). In both cases nothing is written. `<id>` is the `id` of the definition. |

### The fields of a game

The base class sets them before it calls `init`.

| Field | Content |
|---|---|
| `self.screen` | The [screen](#the-screen). |
| `self.context` | The [context](#the-context). |
| `self.random` | A [random generator](#the-random-generator), seeded with a number the console draws from the clock, from 1 to 2147483646. |
| `self.save` | A copy of the save read from the cartridge, cleaned to the limits by [`SpiffBoy.SaveData.clean`](#spiffboysavedata); an empty table on a new cartridge. Changing it writes nothing until `self:persist()`. |
| `self.chip` | The [sound chip](#the-sound-chip). |
| `self.sequencer` | The [sequencer](#the-sequencer). The console creates a new one each time it starts the game. |
| `self.link` | The [link port](#the-link-port). |

### The context

`self.context` gives the art of the cartridge. Only `art` exists on it. Reading any other member raises `SpiffBoy: [SB-HIDDEN] the context of the console has no <member>; a game reaches only art`, and writing any field raises `SpiffBoy: [SB-READONLY] a game cannot write <field> on the context of the console`.

| Field | Content | Edges |
|---|---|---|
| `art(name)` | Loads `name.png` from the `art` folder of the definition, in the mod named by `mod`, with hard pixel edges, and returns the texture. Each file is loaded once, then kept. | Returns nil when the file does not exist, and writes `SpiffBoy: [SB-ART-MISSING] missing texture <path>` once in the log. A texture can still be loading during the first frames: the drawing methods skip it until it is ready. Give the name without `.png`. Raises `SpiffBoy: [SB-ART-MOD] the mod <mod> is not in the mod list of the game` when the `mod` of the definition is not loaded. |

## The screen

The screen of the game is `self.screen`, also given to `draw`. [Screen and art](03-screen-and-art.md) explains the shades, the masks, the layered sheets and the font.

| Member | Content |
|---|---|
| `screen.width` | 180. |
| `screen.height` | 120. |
| `screen.calls` | The draw calls of the current frame so far, counted from 0 at the start of each frame. |

Only the members on this page exist on the screen. Reading any other member raises `SpiffBoy: [SB-HIDDEN] the screen of the console has no <member>; a game reaches only ...`, with the list of the members, and writing any field raises `SpiffBoy: [SB-READONLY] a game cannot write <field> on the screen of the console`.

These rules hold for every drawing method:

- `x` and `y` are taken down to the whole pixel. Sizes given in screen pixels (`w` and `h` of `rect`, `sprite` and `tinted`) too.
- A colour `r, g, b` (each from 0 to 1) is drawn as the nearest of the four shades, at full opacity. `a` has no visible effect. A method that takes a colour raises an error when `r`, `g` or `b` is missing, except the text methods.
- A `shade` argument is 1 to 4, 1 when left out. Any other value raises `SpiffBoy: [SB-SHADE] the palette of the screen has no shade <shade>`.
- A texture that is nil or still loading draws nothing and costs no draw call.

### Drawing methods

| Call | Draws | Draw calls | Edges |
|---|---|---|---|
| `screen:clear(r, g, b)` | Fills the whole screen. | 1 | |
| `screen:rect(x, y, w, h, r, g, b[, a])` | Fills a rectangle. | 1 | The call is counted whatever the size, 0 included. |
| `screen:sprite(texture, x, y[, w, h, a, shade])` | A whole mask, its top left corner at `x, y`, at the size of the texture, or stretched to `w` by `h`. | 1 | `w` and `h` nil keep the size of the texture. |
| `screen:tinted(texture, x, y, w, h, r, g, b[, a])` | The same as `sprite`, with a colour in place of a shade. | 1 | `w` and `h` may be nil. |
| `screen:sheet(texture, sx, sy, sw, sh, x, y[, a, shade])` | The region at `sx, sy`, `sw` by `sh` pixels of the texture, at the same size on the screen. | 1 | `sx`, `sy`, `sw` and `sh` are used as given. |
| `screen:layers(texture, sx, sw, sh, x, y[, shades])` | One cell of a [layered sheet](03-screen-and-art.md#layered-sheets-sprites-in-several-shades): for each shade `s` drawn, the region at `sx, (s - 1) * sh`, `sw` by `sh`, in shade `s`. | 1 per shade drawn: the length of `shades`, 4 without it | An empty list draws nothing and costs nothing. A shade of the list outside 1 to 4 raises the shade error. |
| `screen:rotated(texture, cx, cy, degrees, w, h[, a, shade])` | A whole mask with its centre at `cx, cy`, stretched to `w` by `h`, turned by `degrees`. A positive angle turns it clockwise. | 1 | `w` and `h` are required and are used as given; a missing one raises an error. |
| `screen:number(value, x, y, digits, align, minDigits[, shade])` | `value` taken down to a whole number, padded with zeros to `minDigits` characters, with the strip `digits` of the ten digits 0 to 9. `align` is `"right"` (x is the right edge), `"centre"`, or anything else for the left edge. | 1 per character, padding zeros included | `digits` nil draws nothing. `value` nil raises an error. A negative value draws its minus sign as one more character, which costs one call and has no cell in the strip. |

### Text methods

The text methods write with the pixel font of the screen. A text is a string.

| Call | Does | Returns | Draw calls | Edges |
|---|---|---|---|---|
| `screen:text(str, x, y[, r, g, b, a])` | Writes a line, its left edge at `x`, its top at `y`. | Nothing. | 1 per glyph drawn | Without a colour the text is drawn in shade 4. Spaces, characters the font lacks and invisible format characters cost nothing; each accent mark drawn on a letter costs one. A character the font lacks is named once in the log: `SpiffBoy: [SB-GLYPH] pixel font has no glyph for code point <n>`. The glyphs of a font page still loading are left out and cost nothing. |
| `screen:textCentre(str, x, y[, r, g, b, a])` | Writes a line centred on `x`: its left edge at `x` minus half its width, taken down to the whole pixel. | Nothing. | As `text` | As `text`. |
| `screen:textRight(str, x, y[, r, g, b, a])` | Writes a line whose right edge is at `x`. | Nothing. | As `text` | As `text`. |
| `screen:textWidth(str)` | Measures a line. | Its width in pixels. | 0 | A character the font lacks counts 0. |
| `screen:lineHeight()` | | The height of a line: 14 pixels, 16 when the game runs in Thai. | 0 | |
| `screen:wrapText(str, maxWidth)` | Splits a text into lines no wider than `maxWidth`, breaking after spaces, beside Chinese, Japanese and Korean characters, and between Thai syllables. | A list of strings. | 0 | An empty string gives an empty list. The spaces at a break are dropped, and the spaces at the end of each line are removed. A word wider than `maxWidth` is cut between two glyphs; a line always holds at least one glyph. A line break character `"\n"` does not break the line: the font has no glyph for it, so it counts 0 and is named in the log. |

### The draw call limit

A frame allows 300 draw calls. The 301st raises `SpiffBoy: [SB-DRAW-LIMIT] a frame went past 300 draw calls` and the game crashes in `draw`. [The draw call limit](03-screen-and-art.md#the-draw-call-limit) shows how to measure and how to stay under it.

## The input state

`tick` receives `inputs`, a list. The console always passes one entry: `inputs[1]` is the input state of the player holding the console. [The inputs](02-how-a-cartridge-works.md#the-inputs) shows them in use.

| Field or call | Content or effect | Returns | Edges |
|---|---|---|---|
| `held[key]` | True while the button is down. | | `key` is `up`, `down`, `left`, `right`, `a`, `b` or `start`. A released button is `false`, never nil. Any other key raises `SB-HIDDEN`. |
| `pressed[key]` | True on the one tick the button went down. | | The same keys. False on every other tick, never nil. A keyboard key, a click on a drawn button, or A, B, Start or a direction of the pad of a controller pressed and released between two ticks still gives one tick of `pressed`. With several ticks in one frame, only the first of them sees the press. |
| `input:axes()` | Reads the directions held. | Two numbers, horizontal and vertical, each -1, 0 or 1. | Left and right held together give 0, as do up and down. |

Only `held`, `pressed` and `axes` exist on an input state, and only the seven keys above in `held` and `pressed`. Reading anything else raises `SpiffBoy: [SB-HIDDEN] the input of the console has no <member>; ...`, or `the held table` and `the pressed table` for a key, such as `A` written for `a`. Writing any field raises `SpiffBoy: [SB-READONLY] a game cannot write <field> on the input of the console`, or on its held or pressed table.

A direction on a controller is held when the stick or the pad goes past 0.45 of its travel.

## The random generator

`self.random` is a `SpiffBoyRandom` (`require "SpiffBoy/Core/Random"`). The same seed gives the same numbers in the same order. [The random generator](02-how-a-cartridge-works.md#the-random-generator) says when to use it.

| Call | Does | Returns | Edges |
|---|---|---|---|
| `SpiffBoyRandom.new(seed)` | Creates a generator seeded with `seed`. | The generator. | As `reseed`. |
| `random:reseed(seed)` | Starts the sequence again from `seed`. | Nothing. | Anything but a number raises `SpiffBoy: [SB-SEED] a seed is a number, not <seed>`. The sign and the fraction are dropped, so 5, -5 and 5.7 give the same sequence. A seed that comes to 0 (0, or a multiple of 2147483647) is taken as 1. |
| `random:float()` | Advances the generator. | A number from 0 (included) to 1 (excluded). | |
| `random:int(low, high)` | Advances the generator. | A whole number from `low` to `high`, both included. | Neither argument is checked: give whole numbers with `low` at most `high`. `int(n, n)` returns `n`. |
| `random:range(low, high)` | Advances the generator. | A number from `low` (included) to `high` (excluded). | |
| `random:chance(p)` | Advances the generator. | True with the probability `p`. | `p` of 0 or less is always false, `p` of 1 or more always true. |
| `random:next()` | Advances the generator. | Its raw state, a whole number from 1 to 2147483646. | |

## The sequencer

`self.sequencer` plays the tunes the cartridge registered. [Tunes and effects](04-sound-and-music.md#tunes-and-effects) explains music and effects.

| Call | Does | Returns | Edges |
|---|---|---|---|
| `sequencer:play(name)` | Plays the tune `name` as the music, from its start, in place of the music playing. A tune with `loop = true` repeats; another one ends on its own. The voices an effect holds stay with the effect until it ends. | Nothing. | A name the cartridge did not register raises `SpiffBoy: [SB-TUNE] <id> has no tune named <name>`; when the cartridge registered no tune at all, `<id>` reads `no game`. Playing the tune that already plays starts it again from its start. |
| `sequencer:stop()` | Stops the music and silences its voices. | Nothing. | Effects keep playing. Without music it changes nothing. |
| `sequencer:effect(name)` | Plays the tune `name` once as a sound effect. It takes each voice its tune uses from the music and from older effects; when it ends, the music plays its last note on those voices again. | Nothing. | An unknown name raises the same error as `play`. The same effect started twice plays twice; the newer one holds the voices. |
| `sequencer:isPlaying()` | | True while a tune plays as the music. | False before the first `play`, after `stop`, and once a tune without loop has ended. |
| `sequencer:setMix(music, effects)` | Sets the level of the music and the level of the effects, each from 0 (silent) to 1 (the levels written in the tunes). The levels apply from the next note on; a note already sounding keeps its level. | Nothing. | A value below 0 is taken as 0, above 1 as 1. Give both numbers. |

The levels of `setMix` stay until the next `setMix`: `play`, `stop` and `effect` do not change them. Both are 1 until the game calls `setMix`. They come back to 1 and 1 only when the console starts the game again, with a new sequencer.

An unknown name raised in `tick` crashes the game in `tick`; in `init`, at the stage `init`.

Only these five methods exist on the sequencer. Reading any other member raises `SpiffBoy: [SB-HIDDEN] the sequencer of the console has no <member>; a game reaches only effect, isPlaying, play, setMix, stop`, and writing any field raises `SpiffBoy: [SB-READONLY] a game cannot write <field> on the sequencer of the console`.

## The sound chip

`self.chip` is the sound chip of the console; its constants come with `require "SpiffBoy/Core/Chip"`. The sequencer plays on it; a game writes its registers only to make sounds by hand. The [Sound chip reference](14-sound-chip-reference.md#registers) describes every register.

| Call | Does | Returns | Edges |
|---|---|---|---|
| `chip:write(register, value)` | Writes the byte `value` in the register, and sends the write to the players nearby. | Nothing. | A register that is not one of the constants below raises `SpiffBoy: [SB-CHIP-REGISTER] chip:write got <register>, which is no sound register`. A value that is not a whole number from 0 to 255 raises `SpiffBoy: [SB-CHIP-VALUE] chip:write got the value <value> for a sound register, out of range`. While the chip is off, every write except to `NR52` is ignored. |
| `chip:loadWave(name)` | Loads the wave table `name` in the wave voice, and sends it to the players nearby. | Nothing. | A name outside the 32 tables raises `SpiffBoy: [SB-CHIP-WAVE] chip:loadWave got <name>, and no wave table has that name`. The names are listed in [Echo and wave tables](04-sound-and-music.md#echo-and-wave-tables). |
| `SpiffBoyChip.isRegister(register)` | | True when the number is one of the registers. | |

| Constants | Values |
|---|---|
| `SpiffBoyChip.NR10` to `NR14` | Pulse 1. |
| `SpiffBoyChip.NR21` to `NR24` | Pulse 2. |
| `SpiffBoyChip.NR30` to `NR34` | Wave. |
| `SpiffBoyChip.NR41` to `NR44` | Noise. |
| `SpiffBoyChip.NR50`, `NR51`, `NR52` | Master level, mixer, power. Clearing bit 7 of `NR52` switches the chip off and clears every voice. |
| `SpiffBoyChip.PULSE1`, `PULSE2`, `WAVE`, `NOISE` | The voices, 1 to 4. `SpiffBoyChip.VOICES` is 4. |
| `SpiffBoyChip.MAX_PERIOD`, `SpiffBoyChip.MAX_LEVEL` | 2047 and 15. |

The sequencer writes the same registers: on a voice the music or an effect uses, its next note writes over what the game wrote.

Only `write` and `loadWave` exist on `self.chip`. Reading any other member raises `SpiffBoy: [SB-HIDDEN] the sound chip of the console has no <member>; a game reaches only loadWave, write`, and writing any field raises `SpiffBoy: [SB-READONLY] a game cannot write <field> on the sound chip of the console`.

## SpiffBoy.Tunes.register

`SpiffBoy.Tunes.register(id, tunes)` (`require "SpiffBoy/Core/Tunes"`, in a client file) compiles the tunes of a cartridge and registers them under its id. It returns the set of tunes. [Registering tunes](04-sound-and-music.md#registering-tunes) shows a complete file and [The notation](04-sound-and-music.md#the-notation) the language of the strings.

| Argument or field | Content | Edges |
|---|---|---|
| `id` | The id of a cartridge already registered. | Not a string, or `tunes` not a table: `SpiffBoy: [SB-REG-TUNES] tunes are registered with a string id and a table of definitions`. No cartridge with that id: `SpiffBoy: [SB-REG-TUNES] tunes are registered under the id of a registered cartridge, and no cartridge has the id <id>`. A second call with the same id: `SpiffBoy: [SB-REG-TUNES] tunes are already registered under the id <id> of the cartridge of the mod <mod>`. |
| `tunes` | A table of tunes by name. | A name that is not a string of at most 32 characters: `SpiffBoy: [SB-REG-TUNES] tune names of <id> are strings of at most 32 characters`. A tune that is not a table: `SpiffBoy: [SB-REG-TUNE] tune <id>.<name> needs a table`. |
| `pulse1`, `pulse2`, `wave`, `noise` | The string of each voice the tune uses. | A value that is neither a string nor an echo table raises an error. Any other key of the tune is ignored, a misspelled voice key included. A tune with no voice: `SpiffBoy: [SB-REG-TUNE] tune <id>.<name> has no voice`. A tune that lasts no time: `... lasts no time`. A fault in a string raises an error naming the tune, the voice and the position. |
| `pulse1` or `pulse2` as `{ echo = "pulse1", delay = 8, drop = 4 }` | Plays the notes of the other pulse voice `delay` (a note length, 1 to 64) later and `drop` (0 to 15) levels softer. | Only a pulse voice echoes, and only a pulse voice written in the same tune; a value out of range raises an error. |
| `loop` | `true` to repeat the tune. | Any other value, `nil` included, gives a tune that ends. A loop point at the end of the tune: `... loops from its end`. Voices with their loop points at different times raise an error. |

## SpiffBoy.GameTexts.of

`SpiffBoy.GameTexts.of(id)` (`require "SpiffBoy/Framework/GameTexts"`) returns the text function of the cartridge `id`. [Texts and translations](06-texts-and-translations.md) explains the files.

| Call | Does | Returns | Edges |
|---|---|---|---|
| `SpiffBoy.GameTexts.of(id)` | Makes the text function of the cartridge. | A function `gameText(key, ...)`. | The id is not checked here: the first call of the function raises `SpiffBoy: [SB-TEXTS-ID] no cartridge registered with the id <id>` when no cartridge has it. |
| `gameText(key, ...)` | Reads the key in the language of the game, in the file `<texts><LANG>.json` of the definition, and puts the arguments in `%1` to `%9`. | The text. | A key missing in the language, or a language without a file, falls back to `EN.json`. A key missing there too returns the key itself and writes `SpiffBoy: [SB-TEXT-MISSING] the game <id> has no text <key>` once in the log. A key whose value is `null` counts as missing. An argument nil gives nothing; a whole number is written without decimals; any other value with `tostring`. `%%` gives `%`; any other `%` is kept as it is. A file that is not valid JSON, holds no JSON object or has no `"UI"` section raises an error naming the game, the language and the file. |

Each language file is read the first time a text asks for it, then kept. The language is read on every call.

## SpiffBoy.Cartridges.register

`SpiffBoy.Cartridges.register(definition)` (`require "SpiffBoy/Framework/Cartridges"`, in a shared file) registers a cartridge and returns its definition. [The definition](02-how-a-cartridge-works.md#the-definition) explains each field. Every error message starts with `SpiffBoy: [<code>] cartridge <id> `.

| Field | Content | Edges |
|---|---|---|
| `id` | The name of the game. | Missing, not a string, or a definition that is not a table: `SpiffBoy: [SB-REG-CARTRIDGE] a cartridge definition needs a string id`. |
| `api` | The version of the framework the game is written for, a whole number from 1. `SpiffBoy.API_VERSION` is 1. | Missing or below 1: `needs the api version of SpiffBoy it was written for, such as api = 1`. Above `SpiffBoy.API_VERSION`: `needs a newer SpiffBoy (api <api>, this SpiffBoy has 1)`. |
| `item` | The full type of the cartridge item, `Module.ItemName`. | Not a string holding a dot: `needs the full type of its item, such as MyMod.MyCartridge`. Longer than 64 characters: `has an item type of <n> characters, at most 64 are allowed`. |
| `title` | The title printed on the paper label when the art folder holds no `label.png`. | Not a string: `needs a title`. |
| `game` | The global name of the game class. | Not a string: `needs the global name of its game class`. A name no mod defines shows the missing game on the console and writes `SpiffBoy: [SB-GAME-CLASS] no game class named <game>`. |
| `mod` | The id of the mod that holds the art and the texts. | Not a string: `needs the id of the mod that holds its files`. |
| `art` | The art folder, from the version folder of the mod, ending with `/`. | Not such a string: `needs the folder of its art in its mod, ending with a slash, ...`. |
| `texts` | The folder of the text files, from the version folder of the mod, ending with `/`. | Not such a string: `needs the folder of its language files in its mod, ending with a slash, ...`. |
| `loot` | `{ weight = n }`, or `{ weight = n, lists = { ... } }`. [Loot](08-the-cartridge-item.md#loot). | Missing: the registration writes `{ weight = 2 }` in the definition. Not a table: `needs a loot table`. A weight that is not a number of zero or more: `needs a loot weight of zero or more`. `lists` not a table: `needs a list of loot list names, or none`. A weight of 0 never spawns. A list name that is not a loot list of the game is skipped. |

The registration also stops with an error naming both cartridges and both mods when a cartridge of another mod has the same `id`, or another cartridge has the same `item` or the same `game`. The same `id` registered again by the same mod replaces the earlier definition at its place.

When a game session starts, the console writes a line in the log for each cartridge whose `item` no item script defines, or whose item lacks the tag `spiffboy:cartridge` ([Dismantling](08-the-cartridge-item.md#dismantling)).

| Other members | Content |
|---|---|
| `SpiffBoy.Cartridges.SHADES` | The four shades, darkest first, each `{ r, g, b }` from 0 to 1. |
| `SpiffBoy.Cartridges.byId(id)` | The definition registered with that id, or nil. |

## SpiffBoy.SaveData

`SpiffBoy.SaveData` (`require "SpiffBoy/Core/SaveData"`) holds the limits of a save and the functions that check it. [Saving](05-saving.md) explains when and how to save.

| Call | Does | Returns | Edges |
|---|---|---|---|
| `SpiffBoy.SaveData.check(save)` | Checks the save against every limit. | Nil when it fits; otherwise the message of the first broken limit met, with its place, such as `the save at records.names.1 holds a string of 140 characters, at most 128 are kept`. | A value that is not a table returns `the save is a <type>, not a table`. |
| `SpiffBoy.SaveData.measure(save)` | Counts the entries of the save as the limit of 512 counts them: every key of the save and of the tables it holds. | A whole number. | A value that is not a table raises `SpiffBoy: [SB-SAVE-TABLE] a save is measured as a table, not a <type>`. Tables nested deeper than the limit are not counted. |
| `SpiffBoy.SaveData.clean(value)` | Copies a save within the limits, as the console does when it loads one. | The copy. | A value that is not a table gives an empty table. A string too long is cut to 128 characters. A key that is not allowed, a value of another kind, a number that is not finite and a table nested too deep are dropped. Past the 512th entry, everything is dropped. |

### The save limits

| Constant | Value | Limit |
|---|---|---|
| `SpiffBoy.SaveData.MAX_KEY` | 32 | A key is a string of at most 32 characters or a whole number. |
| `SpiffBoy.SaveData.MAX_STRING` | 128 | A string holds at most 128 characters. |
| `SpiffBoy.SaveData.MAX_DEPTH` | 6 | Tables nest up to 6 levels, the save itself counting as the first. |
| `SpiffBoy.SaveData.MAX_ENTRIES` | 512 | At most 512 entries in all. |

A value is a finite number, a string, a boolean or a table. In multiplayer the server checks every save it receives the same way and takes at most 10 save messages per player per second; it drops the others without an error.

## The link port

`self.link` is the port of the link cable. [The link cable](07-link-cable.md) explains the cable and lockstep.

| Call | Does | Returns | Edges |
|---|---|---|---|
| `link:isConnected()` | | True while the cable joins two consoles, both switched on, both running the same cartridge item. | |
| `link:seat()` | | 1 on the console that holds the cable, 2 on the other, nil when the console is linked to none. | The seat is given as long as the cable is plugged, even while `isConnected()` is false. |
| `link:send(message)` | Queues a message for the other console. | True when queued, false when `isConnected()` is false or when 4 messages were already queued this tick. | A message that is not a string of 1 to 16 bytes, every byte below 256, raises `SpiffBoy: [SB-LINK-MESSAGE] link:send got <message>, and a link message is a text of 1 to 16 bytes`, plugged or not. Call it with a colon. |
| `link:receive()` | Takes the next message received. | The message, or nil when none waits. | |

The port sends the queued messages in batches, every 100 ms or as soon as 24 are queued. It keeps at most 256 messages waiting and drops the oldest beyond that. A batch that arrives after a newer one is dropped.

A connection that ends while the port is in use freezes the console ([When the connection ends](07-link-cable.md#when-the-connection-ends)). Every call of `send` with a valid message counts as a use, even one that returns false; a call of `receive` counts only when it returns a message. The use lasts one second.

Reading any other member of the port raises `SpiffBoy: [SB-HIDDEN] the link port of the console has no <member>; a game reaches only isConnected, receive, seat, send`, and writing any field raises `SpiffBoy: [SB-READONLY] a game cannot write <field> on the link port of the console`.

Back to the [README](../README.md).
