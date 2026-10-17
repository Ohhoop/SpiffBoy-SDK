# 4. Sound and music

A cartridge ships no sound file. It ships notes, written as text in a music notation close to the MML of old computers, and the sound chip of the console plays them. You register the tunes once, and the game asks the sequencer to play them by name.

In multiplayer, the console sends the players nearby only the name of each tune it starts, and their computer plays the same notes on its own copy of the chip. That is why a cartridge registers its tunes on every client, under its id.

## The chip

The chip has four voices, mixed together. Each voice plays one note at a time.

| Voice | Key in a tune | Sound | Usual role |
|---|---|---|---|
| Pulse 1 | `pulse1` | A square wave with four widths (duties) and a pitch sweep | the melody, sweeping effects |
| Pulse 2 | `pulse2` | A square wave with four widths | the accompaniment, short effects |
| Wave | `wave` | A table of samples, chosen among 32 built in tables | the bass |
| Noise | `noise` | A noise generator | drums, explosions, hits |

## Tunes and effects

The sequencer, `self.sequencer`, plays a tune in one of two ways:

- **As the music**, with `self.sequencer:play(name)`. One music plays at a time; playing another replaces it. A tune with `loop = true` repeats until another music plays or the music stops; a tune without `loop` ends on its own.
- **As a sound effect**, with `self.sequencer:effect(name)`. It plays once, on top of the music, and borrows the voices it uses: the music is silent on those voices while the effect plays, then plays its last note on them again. Several effects can overlap; a newer effect takes a voice from an older one.

| Call | Effect |
|---|---|
| `self.sequencer:play(name)` | Plays a tune as the music, from its start. |
| `self.sequencer:stop()` | Stops the music. Effects keep playing. |
| `self.sequencer:effect(name)` | Plays a tune once as a sound effect. |
| `self.sequencer:isPlaying()` | True while a tune plays as the music; false once a tune without loop has ended. |
| `self.sequencer:setMix(music, effects)` | Sets the level of the music and of the effects, each from 0 (silent) to 1 (as written). Applies from the next note. |
| `self.sequencer:mix()` | Returns the two levels. |

Playing a name the game did not register is an error, and the game crashes with `SpiffBoy: <Id> has no tune named <name>`. Keep the names in constants, as both examples do, so a typing mistake shows at once.

## Registering tunes

Register the tunes in a client file, when it loads, under the **id of your cartridge**: the console finds the tunes of a cartridge by that id. `Music.lua` of Hello SpiffBoy:

```lua
require "SpiffBoySDK/Core"
require "SpiffBoy/Core/Tunes"

SpiffBoySDK.HelloSpiffBoy = SpiffBoySDK.HelloSpiffBoy or {}

local Music = {}
SpiffBoySDK.HelloSpiffBoy.Music = Music

Music.THEME = "theme"
Music.HELLO = "hello"
Music.MOVE = "move"
Music.SELECT = "select"
Music.TOGGLE = "toggle"

SpiffBoy.Tunes.register("HelloSpiffBoy", {
    [Music.THEME] = {
        loop = true,
        pulse1 = "t120 @1 v10 y0 q6 l8 o5"
            .. " c e g e f a g4 | e g >c< g f d e4"
            .. " | c e g e f a g4 | a f e d c4 r4",
        wave = "t120 @11 v2 l4 o3 c g f g | c g g c | c g f g | f g c r",
        noise = "t120 l8 [v9 y1 n{40 72 113} r v4 y1 n32 r v7 y2 n56 r v4 y1 n32 r]4",
    },
    [Music.HELLO] = { pulse2 = "t200 @2 v12 y2 l16 o5 g >e8" },
    [Music.MOVE] = { pulse2 = "t240 @3 v8 y1 l32 o6 c" },
    [Music.SELECT] = { pulse2 = "t220 @2 v11 y1 l32 o5 c g >c" },
    [Music.TOGGLE] = { pulse2 = "t240 @1 v10 y1 l32 o5 e <e" },
})
```

- `SpiffBoy.Tunes.register(id, tunes)` takes the id of the cartridge and a table of tunes by name. A name is a string of at most 32 characters.
- The id must be the one of a cartridge already registered, and a game registers its tunes once, in one call. Another id, or a second call with the same id, stops the file with an error. The definition, a shared file, always loads before the client file that registers the tunes.
- Each tune gives one string per voice it uses, and `loop = true` to repeat.
- Long strings are split with `..` for reading. `|` marks the bars for the reader; the chip ignores it.
- The strings are compiled when the file loads. A mistake stops the file with an error naming the tune, the voice and the position of the faulty character, such as `SpiffBoy: tune HelloSpiffBoy.theme, voice pulse1, character 31: ...`.

The game then plays them:

```lua
self.sequencer:play(Music.THEME)
self.sequencer:effect(Music.HELLO)
```

## The notation

A voice string is a list of commands read left to right. Spaces, line breaks and `|` separate them. Without a command saying otherwise, a voice starts at tempo 120, quarter notes, octave 4, the highest level and the 50 % width.

### Notes and rests

| Command | Meaning |
|---|---|
| `c d e f g a b` | A note. `+` or `#` after it makes it sharp, `-` flat: `f+`, `b-`. Then an optional length and dots: `c4`, `e8.`. |
| `r` | A rest, with an optional length and dots: `r4`. |
| `^` | After a note, ties another length to it: `c4^8` lasts a quarter plus an eighth. |
| `l<n>` | The length of notes and rests that give none: `l1` whole, `l2` half, `l4` quarter, `l8` eighth, up to `l64`. |
| `o<n>` | The octave, 1 to 8. The pulses reach down to C of octave 2, the wave voice to C of octave 1. |
| `<` `>` | One octave down, one octave up. |
| `t<n>` | The tempo in beats per minute, 20 to 400. A quarter note is one beat. |

`"t120 l8 o5 c e g e f a g4"` plays eighth notes at 120 beats per minute in octave 5, the last note a quarter.

### The sound of a note

| Command | Meaning |
|---|---|
| `v<n>` | The level: 0 to 15 on the pulses and the noise; 0 to 3 on the wave voice (0 silent, 1 quarter, 2 half, 3 full). |
| `y<n>` | An envelope that lowers the level one step every `n/64` second, `n` from 1 to 7. `y0` holds the level. Not on the wave voice. |
| `u<n>` | An envelope that raises the level one step every `n/64` second. |
| `@<n>` | The timbre. On a pulse, the width: `@0` 12.5 %, `@1` 25 %, `@2` 50 %, `@3` 75 %; several digits make a sequence that changes width every frame, such as `@0213`. On the wave voice, the number of a wave table (below). |
| `q<n>` | The gate, 1 to 8: how many eighths of each note sound before it is cut. `q8` joins the notes, `q4` makes them short. |

### Movement inside a note

| Command | Meaning |
|---|---|
| `{c e g}` | A chord played as a fast arpeggio: its notes cycle, for the length written after the brace, `{ceg}8`. At most 8 notes. `<` and `>` inside move the octave for the chord only. |
| `x<n>` | Frames per step of the arpeggios, 1 to 16. |
| `~<d>,<s>[,<w>]` | Vibrato: the pitch swings by `d` over a cycle of `s` frames, after waiting `w` frames. `~0` stops it. |
| `p<n>` | Portamento: each note glides from the previous pitch over `n` frames. `p0` stops it. |
| `s<p>,<n>` | Sweep, on pulse 1 only: the pitch rises every `p/128` second; `s<p>,-<n>` makes it fall. `s0` stops it. |

A frame here is one tick of the console, a sixtieth of a second.

### Noise

| Command | Meaning |
|---|---|
| `n<v>` | On the noise voice, plays the noise setting `v` (0 to 255) for the current length. |
| `n{48 80 113}` | Steps through settings, one per frame, and holds the last: a drum. At most 32 settings. |

The higher four bits of a setting choose how low the noise sounds. Some settings: `n16` bright hiss, `n32` softer hiss, `n80` dark hat, `n64` snare like burst, `n113` low rumble, `n{48 80 113}` a kick drum.

### Structure

| Command | Meaning |
|---|---|
| `[ ... ]<n>` | Repeats the group `n` times, 1 to 64: `[c e g e]4`. |
| `L` | The loop point: a looping tune repeats from here instead of its start, after an intro for example. Every voice that has an `L` must reach it at the same time. |

Each voice keeps its own tempo and position. A looping tune loops at the end of its longest voice, every voice restarting together, so write every voice to the same length.

### Echo and wave tables

A pulse voice can echo the other pulse voice instead of having its own string:

```lua
pulse2 = { echo = "pulse1", delay = 8, drop = 4 },
```

Pulse 2 then plays every note of pulse 1 an eighth later (`delay` is a note length) and 4 levels softer (`drop`, 0 to 15).

The wave tables, chosen with `@` on the wave voice: 0 triangle, 1 sawtooth, 2 sine, 3 square, 4 organ, 5 bass, 6 stairs, 7 hollow, 8 pulse25, 9 pulse12, 10 sawdown, 11 round, 12 halfsine, 13 bell, 14 chime, 15 reed, 16 nasal, 17 formant, 18 ramp, 19 doublesaw, 20 octaves, 21 buzz, 22 piano, 23 strings, 24 brass, 25 flute, 26 glass, 27 metal, 28 thump, 29 grit, 30 wobble, 31 steps.

## Reading the Hello SpiffBoy theme

The `pulse1` string of the theme opens with `t120 @1 v10 y0 q6 l8 o5`: tempo 120, the 25 % width, level 10, no fade, each note sounding for 6 eighths of its length, eighth notes, octave 5. Then come four bars in C major; `>c<` goes one octave up for a single note and comes back.

The `wave` string is the bass: wave table 11 (`round`), half level, quarter notes in octave 3. Its four bars of four quarters last as long as the melody, so both loop together.

The `noise` string is one bar of drums (a kick, a soft hat, a snare, a soft hat, with rests between) repeated four times with `[ ... ]4`: four bars again.

The effects are one short string each, fast (`t200` to `t240`), short (`l16`, `l32`) and quickly faded (`y1`, `y2`).

## Writing music for a game

- Give the effects a voice of their own. The Hello SpiffBoy theme uses `pulse1`, `wave` and `noise` and leaves `pulse2` free; all its effects use `pulse2`, so an effect never cuts the melody. When the music needs all four voices, an effect silences one of them for its length: choose which.
- Keep effects short, a fraction of a second: an effect holds its voice away from the music.
- Give each voice one job: melody on pulse 1, accompaniment on pulse 2, bass on the wave voice, drums on the noise.
- Registers that work: bass in octave 2 or 3, chords in 3 or 4, melody in 4 or 5, octave 6 for an effect or a single peak.
- Levels that work: melody `v10` to `v12`, accompaniment `v5` to `v8`, wave bass `v2` or `v3`, hats `v2` to `v4`, kick around `v9`.
- Write tunes for your own cartridge; do not reuse the tunes or the effects of another cartridge.
- An option to switch the music off can keep the effects through the mix, as in Spiff-Pong:

  ```lua
  function Game:applyMix()
      if self.options.music then
          self.sequencer:setMix(1, 1)
      else
          self.sequencer:setMix(0, 1)
      end
  end
  ```

The [Sound chip reference](14-sound-chip-reference.md#example-scores) holds complete example scores, a [drum kit](14-sound-chip-reference.md#drum-kit) and [effect recipes](14-sound-chip-reference.md#effects) such as a coin, a jump, a laser and an explosion.

## Music after a jingle

A tune without `loop` ends on its own and `isPlaying()` turns false. Spiff-Pong uses it to start the title music once a jingle is over:

```lua
function Game:keepMusic(name)
    if not self.sequencer:isPlaying() then
        self.sequencer:play(name)
    end
end
```

Each menu calls `self:keepMusic(Music.TITLE)` in its tick: after the jingle of a won or lost match ends, the title music starts by itself.

## The chip registers

Under the sequencer, `self.chip` gives the registers of the chip: `self.chip:write(register, value)` writes a byte in a register (`SpiffBoyChip.NR10` to `SpiffBoyChip.NR52`), and `self.chip:loadWave(name)` loads a wave table by its name. The [Sound chip reference](14-sound-chip-reference.md#registers) describes every register, with an example of [a note written by hand](14-sound-chip-reference.md#writing-a-note-by-hand). Tunes are lighter on the network: a tune travels as one name when it starts, while every register write travels on its own to the players nearby.

Next: [Saving](05-saving.md).
