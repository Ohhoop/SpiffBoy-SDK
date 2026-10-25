# 14. Sound chip reference

This page lists what the sound chip of the console offers a game: its voices, its registers, its wave tables, its noise settings, the limits of the music notation, and example scores to start from. [Sound and music](04-sound-and-music.md) explains tunes, effects and the notation; this page is the reference to keep open beside it.

## Two ways to drive the chip

A game reaches the chip through two objects the framework sets on it:

| Object | Use |
|---|---|
| `self.sequencer` | Plays the tunes registered by the game, as music or as effects. |
| `self.chip` | The hardware: `self.chip:write(register, value)` writes a byte in a register, `self.chip:loadWave(name)` loads a wave table in the wave voice. |

Tunes cover music and effects. Writing registers by hand gives a sound that the notation cannot write, at the cost of one network event per write in multiplayer.

## Voices

| Voice | Constant | Key in a tune | Registers | Sound |
|---|---|---|---|---|
| Pulse 1 | `SpiffBoyChip.PULSE1` (1) | `pulse1` | NR10 to NR14 | Square wave, duty 12.5, 25, 50 or 75 %, with a frequency sweep |
| Pulse 2 | `SpiffBoyChip.PULSE2` (2) | `pulse2` | NR21 to NR24 | Square wave, duty 12.5, 25, 50 or 75 % |
| Wave | `SpiffBoyChip.WAVE` (3) | `wave` | NR30 to NR34 | One of the 32 [wave tables](#wave-tables) |
| Noise | `SpiffBoyChip.NOISE` (4) | `noise` | NR41 to NR44 | A 15 bit or 7 bit noise register, see [Noise](#noise) |

The chip is mono: the four voices are mixed into one sound.

## Pitch

A tone voice takes an 11 bit period, 0 to 2047: its low byte in NRx3 and its three high bits in bits 2 to 0 of NRx4.

| Voice | Frequency in hertz |
|---|---|
| Pulse 1 and 2 | `131072 / (2048 - period)` |
| Wave | `65536 / (2048 - period)` |

A tone above 16384 hertz is silent. The same period plays one octave lower on the wave voice than on a pulse.

The period of a frequency is `2048 - floor(131072 / frequency + 0.5)` on a pulse. The notation tunes A of octave 4 to 440 hertz. Periods on a pulse voice, which are also the periods of the same notes one octave lower on the wave voice:

| Octave | C | C# | D | D# | E | F | F# | G | G# | A | A# | B |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 3 | 1046 | 1102 | 1155 | 1205 | 1253 | 1297 | 1339 | 1379 | 1417 | 1452 | 1486 | 1517 |
| 4 | 1547 | 1575 | 1602 | 1627 | 1650 | 1673 | 1694 | 1714 | 1732 | 1750 | 1767 | 1783 |
| 5 | 1798 | 1812 | 1825 | 1837 | 1849 | 1860 | 1871 | 1881 | 1890 | 1899 | 1907 | 1915 |

The lowest note of a pulse is C of octave 2, the lowest note of the wave voice C of octave 1.

## Registers

`self.chip:write(register, value)` takes one of the constants below and a whole number from 0 to 255. Any other register or value raises an error (`SpiffBoy: [SB-CHIP-REGISTER] chip:write got ..., which is no sound register`, `SpiffBoy: [SB-CHIP-VALUE] chip:write got the value ... for a sound register, out of range`). Bits are numbered from 7 (highest) to 0.

| Constant | Address | Voice | Bits |
|---|---|---|---|
| `SpiffBoyChip.NR10` | `0x10` | Pulse 1 | 6-4 sweep period, 3 sweep direction (1 lowers the pitch), 2-0 sweep shift |
| `SpiffBoyChip.NR11` | `0x11` | Pulse 1 | 7-6 duty (0 = 12.5 %, 1 = 25 %, 2 = 50 %, 3 = 75 %), 5-0 length load |
| `SpiffBoyChip.NR12` | `0x12` | Pulse 1 | 7-4 initial level, 3 envelope direction (1 rises), 2-0 envelope period |
| `SpiffBoyChip.NR13` | `0x13` | Pulse 1 | 7-0 low byte of the period |
| `SpiffBoyChip.NR14` | `0x14` | Pulse 1 | 7 trigger, 6 length enable, 2-0 high bits of the period |
| `SpiffBoyChip.NR21` | `0x16` | Pulse 2 | as NR11 |
| `SpiffBoyChip.NR22` | `0x17` | Pulse 2 | as NR12 |
| `SpiffBoyChip.NR23` | `0x18` | Pulse 2 | as NR13 |
| `SpiffBoyChip.NR24` | `0x19` | Pulse 2 | as NR14 |
| `SpiffBoyChip.NR30` | `0x1A` | Wave | 7 voice on |
| `SpiffBoyChip.NR31` | `0x1B` | Wave | 7-0 length load |
| `SpiffBoyChip.NR32` | `0x1C` | Wave | 6-5 level (0 silent, 1 full, 2 half, 3 quarter) |
| `SpiffBoyChip.NR33` | `0x1D` | Wave | 7-0 low byte of the period |
| `SpiffBoyChip.NR34` | `0x1E` | Wave | 7 trigger, 6 length enable, 2-0 high bits of the period |
| `SpiffBoyChip.NR41` | `0x20` | Noise | 5-0 length load |
| `SpiffBoyChip.NR42` | `0x21` | Noise | as NR12 |
| `SpiffBoyChip.NR43` | `0x22` | Noise | 7-4 clock shift, 3 narrow register (7 bits), 2-0 divisor code |
| `SpiffBoyChip.NR44` | `0x23` | Noise | 7 trigger, 6 length enable |
| `SpiffBoyChip.NR50` | `0x24` | Mixer | 6-4 left master level, 2-0 right master level |
| `SpiffBoyChip.NR51` | `0x25` | Mixer | 7-4 voices on the left, 3-0 voices on the right (bit 0 or 4 pulse 1, 1 or 5 pulse 2, 2 or 6 wave, 3 or 7 noise) |
| `SpiffBoyChip.NR52` | `0x26` | Chip | 7 power |

### Switching a voice on and off

A pulse or noise voice sounds only while bits 7 to 3 of its envelope register (NR12, NR22, NR42) are not all 0; writing 0 there switches it off at once. The wave voice sounds only while bit 7 of NR30 is set. A switched off voice stays silent until a trigger after its converter is on again.

A trigger (bit 7 of NR14, NR24, NR34 or NR44) does this:

- enables the voice when its converter is on;
- reloads the length when it has run out;
- restarts the envelope from its initial level;
- on pulse 1, arms the sweep, and disables the voice at once when the sweep shift is not 0 and the first step would take the period past 2047.

### Lengths, sweep and envelopes

The chip runs a frame sequencer at 512 hertz. It counts the lengths down at 256 hertz, steps the sweep at 128 hertz and the envelopes at 64 hertz.

| Feature | Behaviour |
|---|---|
| Length | With bit 6 of NRx4 set, the voice stops after `64 - load` steps (pulse and noise) or `256 - load` steps (wave), each step 1/256 second. |
| Sweep | Every `period / 128` second, the period of pulse 1 moves by itself shifted right `shift` times: up (higher pitch) with bit 3 clear, down with bit 3 set. The voice stops when the period would pass 2047. A sweep period of 0 does not move the pitch. |
| Envelope | Every `period / 64` second, the level moves one step up or down, between 0 and 15. An envelope period of 0 holds the level. |
| Wave level | The wave voice has no envelope: its level is the code of NR32. |

### Mixer and power

| Register | Behaviour |
|---|---|
| NR50 | The master level is the louder of the two sides: `(level + 1) / 8`. Level 0 is one eighth, not silence. |
| NR51 | A voice is heard when its bit is set on either side. |
| NR52 | Bit 7 clear switches the chip off: every voice and the mixer are cleared (the loaded wave table stays), and every write other than to NR52 is ignored. Bit 7 set switches it on again, silent until NR50 and NR51 are written. |

When the console switches on, the chip starts with the power on, NR50 at `0x77` and NR51 at `0xF3`: full master level, every voice heard. A game only writes the voices it uses.

## Writing a note by hand

`SpiffBoy.Tunes` holds helpers for the register values:

| Helper | Returns |
|---|---|
| `SpiffBoy.Tunes.periodBytes(period)` | The low byte and the high bits of a period, for NRx3 and NRx4. |
| `SpiffBoy.Tunes.envelopeByte(level, up, period)` | The value of NR12, NR22 or NR42: `level` 0 to 15, `up` true to rise, `period` 0 to 7. |
| `SpiffBoy.Tunes.TRIGGER` | `0x80`, the trigger bit of NRx4. |

A C of octave 5 on pulse 1, at level 12, fading one step every 2/64 second:

```lua
require "SpiffBoy/Core/Tunes"

local Chip = SpiffBoyChip
local Tunes = SpiffBoy.Tunes

local C5 = 1798
local HALF_DUTY = 0x80

function MyGame:beep()
    local low, high = Tunes.periodBytes(C5)
    self.chip:write(Chip.NR10, 0)
    self.chip:write(Chip.NR11, HALF_DUTY)
    self.chip:write(Chip.NR12, Tunes.envelopeByte(12, false, 2))
    self.chip:write(Chip.NR13, low)
    self.chip:write(Chip.NR14, Tunes.TRIGGER + high)
end
```

The same on the wave voice, at full level, with a wave table:

```lua
function MyGame:hum()
    local low, high = Tunes.periodBytes(C5)
    self.chip:loadWave("organ")
    self.chip:write(Chip.NR30, 0x80)
    self.chip:write(Chip.NR32, 0x20)
    self.chip:write(Chip.NR33, low)
    self.chip:write(Chip.NR34, Tunes.TRIGGER + high)
end
```

A burst of noise:

```lua
function MyGame:crack()
    self.chip:write(Chip.NR42, Tunes.envelopeByte(12, false, 1))
    self.chip:write(Chip.NR43, 64)
    self.chip:write(Chip.NR44, Tunes.TRIGGER)
end
```

### Registers and tunes together

On every step of the console, the game ticks first, then the sequencer moves the running notes and starts the notes that are due, then the chip runs. The sequencer writes every register of a voice when it starts a note on it, rewrites the period, duty and noise setting while the note moves, and silences the voice with NR12, NR22 or NR42 at 0, or NR30 at 0, at a rest or when the gate cuts a note. A game that writes by hand into a voice a running tune or effect uses is overwritten at the next note of that tune: write by hand only on a voice no tune uses at that moment.

In multiplayer, every `write` and `loadWave` travels to the players nearby as one event, while a tune travels as its name only.

## Wave tables

The wave voice plays one of 32 built in tables of 32 steps. `self.chip:loadWave(name)` loads a table by its name; an unknown name raises `SpiffBoy: [SB-CHIP-WAVE] chip:loadWave got ..., and no wave table has that name`. In the notation, `@<n>` on the wave voice picks a table by its number. A wave voice that writes no `@` plays table 0.

| Number | Name | Number | Name | Number | Name | Number | Name |
|---|---|---|---|---|---|---|---|
| 0 | `triangle` | 8 | `pulse25` | 16 | `nasal` | 24 | `brass` |
| 1 | `sawtooth` | 9 | `pulse12` | 17 | `formant` | 25 | `flute` |
| 2 | `sine` | 10 | `sawdown` | 18 | `ramp` | 26 | `glass` |
| 3 | `square` | 11 | `round` | 19 | `doublesaw` | 27 | `metal` |
| 4 | `organ` | 12 | `halfsine` | 20 | `octaves` | 28 | `thump` |
| 5 | `bass` | 13 | `bell` | 21 | `buzz` | 29 | `grit` |
| 6 | `stairs` | 14 | `chime` | 22 | `piano` | 30 | `wobble` |
| 7 | `hollow` | 15 | `reed` | 23 | `strings` | 31 | `steps` |

## Noise

A noise setting is the byte of NR43, the value written after `n` in the notation:

| Bits | Meaning |
|---|---|
| 7-4 | Clock shift, 0 to 15. A shift above 13 is silent. |
| 3 | 0 for the 15 bit register, whose pattern repeats every 32767 steps; 1 for the 7 bit register, whose pattern repeats every 127 steps. |
| 2-0 | Divisor code, 0 to 7. Code 0 counts as 0.5, the others as themselves. |

The noise register is clocked at `524288 / divisor / 2 ^ (shift + 1)` hertz: the higher the shift or the divisor, the lower the noise.

| Setting | Shift | Register | Divisor | Clock (Hz) | Use |
|---|---|---|---|---|---|
| `n16` | 1 | 15 bit | 0 | 262144 | bright hiss, crash |
| `n32` | 2 | 15 bit | 0 | 131072 | softer hiss, hat |
| `n40` | 2 | 7 bit | 0 | 131072 | attack of the Hello SpiffBoy kick |
| `n48` | 3 | 15 bit | 0 | 65536 | attack of a kick |
| `n56` | 3 | 7 bit | 0 | 65536 | Hello SpiffBoy snare |
| `n64` | 4 | 15 bit | 0 | 32768 | snare burst |
| `n72` | 4 | 7 bit | 0 | 32768 | tail of the Spiff-Pong snare |
| `n80` | 5 | 15 bit | 0 | 16384 | dark hat |
| `n88` | 5 | 7 bit | 0 | 16384 | Spiff-Pong hat |
| `n96` | 6 | 15 bit | 0 | 8192 | low noise |
| `n113` | 7 | 15 bit | 1 | 2048 | low rumble, end of a kick |

`n{48 80 113}` steps through three settings, one per frame, and holds the last: the noise falls from a crack to a thump, a kick drum.

## Notation limits

The values each command accepts, and what a voice starts with when its string does not set it. A value outside its range stops the file with an error naming the tune, the voice and the character.

| Command | Range | Start value |
|---|---|---|
| `t` | 20 to 400 | 120 |
| `l` | 1 to 64, with optional dots | 4 |
| `o` | 1 to 8 | 4 |
| `v` | 0 to 15; 0 to 3 on the wave voice | 15; 3 on the wave voice |
| `y`, `u` | 0 to 7; not on the wave voice | 0 (level held) |
| `@` on a pulse | one to 16 digits, each 0 to 3 | 2 (50 %) |
| `@` on the wave voice | 0 to 31 | 0 (`triangle`) |
| `s<p>,<n>` | `p` 0 to 7, `n` 0 to 7; pulse 1 only | 0 |
| `q` | 1 to 8 | 8 |
| `x` | 1 to 16 | 1 |
| `~<d>,<s>[,<w>]` | `d` 0 to 64, `s` 2 to 64, `w` 0 to 255; not on the noise voice | off |
| `p` | 0 to 255; not on the noise voice | 0 |
| `n` | 0 to 255; a sequence holds 1 to 32 values; noise voice only | none |
| `{ }` | 1 to 8 notes; not on the noise voice | none |
| `[ ]<n>` | 1 to 64 repeats; the expanded string holds at most 65536 characters | none |
| echo `delay` | 1 to 64, a note length | none |
| echo `drop` | 0 to 15 | none |

A frame is one tick of the console, 1/60 second. The name of a tune is a string of at most 32 characters.

An echo copies the notes of the other pulse voice with their tempo, `delay` later and `drop` levels lower, without sweep. In a looping tune, the echoed notes that would fall after the end of the source voice are dropped, so the loop keeps its length.

## Drum kit

One bar of each pattern, on the noise voice, in eighths (`l8`) unless the pattern sets its own length.

| Pattern | Score |
|---|---|
| Kick and snare | `v10 y1 n{48 80 113} r v8 y2 n64 r v10 y1 n{48 80 113} r v8 y2 n64 r` |
| Kick, snare, off beat hats | `v10 y1 n{48 80 113} v4 y1 n80 v8 y2 n64 v4 y1 n80 v10 y1 n{48 80 113} v4 y1 n80 v8 y2 n64 v4 y1 n80` |
| Hats on two and four only | `l4 r v3 y1 n80 r n80` |
| Snare roll fill | `v10 y1 n{48 80 113} r v8 y2 n64 r v8 y2 n64 n64 v9 y2 n64 n64` |
| Crash | `l2 v12 y5 n{16 32 48}` |

In a tune, a pattern goes into a repeat: `noise = "t120 l8 [v10 y1 n{48 80 113} r v8 y2 n64 r v10 y1 n{48 80 113} r v8 y2 n64 r]4"`.

## Effects

Short tunes for `self.sequencer:effect(name)`. Each uses one voice or more and gives it back to the music when it ends.

```lua
SpiffBoy.Tunes.register("ExampleEffects", {
    coin = { pulse2 = "t240 @2 v10 y1 l16 o5 {ceg>c}" },
    oneup = { pulse2 = "t240 @2 v11 y1 l32 o5 e g >c< e g >c" },
    powerup = { pulse2 = "t200 @2 v11 y2 x2 l8 o4 {ceg>c} {dfa>d} {egb>e}" },
    jump = { pulse1 = "t120 @1 v12 y3 s3,5 o4 c4" },
    laser = { pulse1 = "t120 @0 v12 y2 s1,-2 o6 c4" },
    fall = { pulse1 = "t120 @2 v12 y3 o5 g4 p30 <c2" },
    hit = { noise = "t240 l16 v12 y1 n{64 80}" },
    explosion = { noise = "t120 l2 v13 y5 n{32 48 64 80 96 113}" },
    menu = { pulse2 = "t240 @1 v8 y1 l32 o5 g" },
    confirm = { pulse2 = "t200 @2 v10 y2 l16 o5 c e g" },
    lose = {
        pulse1 = "t120 @2 v13 y4 s4,-6 o5 g2",
        pulse2 = "t120 @1 v10 y3 l16 o5 e d+ d c+ c <b b- a a- g g- f",
        noise = "t120 l2 v9 y3 n{32 64 96 113}",
    },
})
```

| Effect | Technique |
|---|---|
| `coin` | A four note arpeggio inside one sixteenth: the chord is heard as one bright note. |
| `powerup` | Three arpeggios in a row, `x2` holding each chord note two frames. |
| `jump` | The sweep raises the pitch until the period passes 2047 and the voice stops by itself. |
| `laser` | The sweep lowers the pitch fast from a high note, with the 12.5 % duty. |
| `fall` | A portamento of 30 frames from the first note down to the second. |
| `explosion` | The noise clock falls one setting per frame while the level decays slowly (`y5`). |
| `lose` | Three voices at once: a falling sweep, a chromatic run down, a falling noise. |

The ids in these examples (`ExampleEffects` and the ones below) stand for the id of your cartridge. SpiffBoy accepts tunes only under the id of a registered cartridge, and only once per id: copy the tunes you take into the single `SpiffBoy.Tunes.register` call of your game, under your own id.

## Example scores

Each block compiles as written, and every voice of a looping tune ends at the same time.

### Menuet in G major

Petzold, three beats to the bar at 116: melody on pulse 1, held chord tones on pulse 2 (`q8`, dotted halves), root and fifth bass in quarters on the `halfsine` table.

```lua
SpiffBoy.Tunes.register("ExampleMenuet", {
    loop = {
        loop = true,
        pulse1 = "t116 @2 v12 y0 q7 l8 o4"
            .. " >d4< g a b >c< | >d4< g4 g4 | >e4 c d e f+< | >g4< g4 g4"
            .. " | >c4 d c< b a | b4 >c< b a g | f+4 g a b g | a2."
            .. " | >d4< g a b >c< | >d4< g4 g4 | >e4 c d e f+< | >g4< g4 g4"
            .. " | >c4 d c< b a | b4 >c< b a g | a4 b a g f+ | g2.",
        pulse2 = "t116 @1 v6 y0 q8 l2. o4"
            .. " b d e d | e d c f+ | b d e d | e d c b",
        wave = "t116 @12 v3 l4 o2"
            .. " g >d< g | g >d< g | c g c | g >d< g"
            .. " | c g c | g >d< g | d a d | d a d"
            .. " | g >d< g | g >d< g | c g c | g >d< g"
            .. " | c g c | g >d< g | d a d | g >d< g",
    },
})
```

### Für Elise

Beethoven, three eighths to the bar at 80, on two voices only: the right hand on pulse 1, the left hand on the wave voice.

```lua
SpiffBoy.Tunes.register("ExampleElise", {
    loop = {
        loop = true,
        pulse1 = "t80 @2 v11 y0 q8 l16 o5"
            .. " r8 r8 e d+ | e d+ e <b >d c | <a8 r c e a | b8 r e g+ b | >c8 r< e >e d+"
            .. " | e d+ e <b >d c | <a8 r c e a | b8 r e >c< b | a8 r4",
        wave = "t80 @12 v3 l16 o2"
            .. " r8 r8 r8 | r8 r8 r8 | a >e a< r r8 | e >e g+< r r8 | a >e a< r r8"
            .. " | r8 r8 r8 | a >e a< r r8 | e >e g+< r r8 | a >e a< r r8",
    },
})
```

### In the Hall of the Mountain King

Grieg, B minor at 112: the theme detached (`q6`) with its echo on pulse 2, then repeated one octave up with the 25 % duty (`@1`), the drums entering with the repeat.

```lua
SpiffBoy.Tunes.register("ExampleMountainKing", {
    loop = {
        loop = true,
        pulse1 = "t112 @2 v11 y0 q6 l8 o3"
            .. " b >c+ d e f+ d f+4 | f c+ f4 f c+ f4 | e c e4 e c e4 | <b >c+ d e f+ d f+4"
            .. " | b a f+ d f+ a b4 | a f+ a4 a f+ a4 | b a f+ d f+ a b4 | b2 r2"
            .. " | @1 v12 o4 b >c+ d e f+ d f+4 | f c+ f4 f c+ f4 | e c e4 e c e4 | <b >c+ d e f+ d f+4"
            .. " | b a f+ d f+ a b4 | a f+ a4 a f+ a4 | b a f+ d f+ a b4 | b2 r2",
        pulse2 = { echo = "pulse1", delay = 8, drop = 5 },
        wave = "t112 @12 v3 l8 o2"
            .. " [bb>b<b]2 [f+f+>f+<f+]2 [cc>c<c]2 [bb>b<b]2 [bb>b<b]2 [f+f+>f+<f+]2 [bb>b<b]2 [f+f+>f+<f+]2"
            .. " [bb>b<b]2 [f+f+>f+<f+]2 [cc>c<c]2 [bb>b<b]2 [bb>b<b]2 [f+f+>f+<f+]2 [bb>b<b]2 [f+f+>f+<f+]2",
        noise = "t112 l4 [r v3 y1 n80 r n80]8"
            .. " l8 [v10 y1 n{48 80 113} r v8 y2 n64 r v10 y1 n{48 80 113} r v8 y2 n64 r]8",
    },
})
```

### Carol of the Bells

Leontovych, A minor, three beats to the bar at 150: the four note motif alone, then its third above on pulse 2, then the bass, then the drums. The later voices start with rests, so each voice enters in turn.

```lua
SpiffBoy.Tunes.register("ExampleCarol", {
    loop = {
        loop = true,
        pulse1 = "t150 @2 v11 y0 q7 l4 o4 [>c4< b8 >c8< a4]16",
        pulse2 = "t150 @1 v7 y0 q7 l4 o5 r2. r2. r2. r2. [e4 d8 e8 c4]12",
        wave = "t150 @12 v3 l2. o2 r r r r r r r r a a a a f f g e",
        noise = "t150 l4 [r r r]12 [v9 y1 n{48 80 113} v4 y1 n80 v8 y2 n64]4",
    },
})
```

### Canon in D

Pachelbel at 72: the ground bass with soft arpeggio chords on pulse 2 (`x2`), the melody entering in quarters, then in eighths up to octave 5, then in quarters again. Four turns of the eight chords.

```lua
SpiffBoy.Tunes.register("ExampleCanon", {
    loop = {
        loop = true,
        pulse1 = "t72 @2 v11 y0 q8 l4 o4"
            .. " r1 r1 r1 r1"
            .. " | >f+4 e4 d4 c+4 | <b4 a4 b4 >c+4 | d4 c+4 <b4 a4 | g4 f+4 g4 e4"
            .. " | >d8 f+8 a8 g8 f+8 d8 f+8 e8 | d8 <b8 >d8 <a8 g8 b8 a8 g8 | f+8 d8 e8 >c+8 d8 f+8 a8 <a8 | b8 g8 a8 f+8 d8 >d8 d8 c+8"
            .. " | f+4 e4 d4 c+4 | <b4 a4 b4 >c+4 | d4 c+4 <b4 a4 | g4 f+4 g4 e4",
        pulse2 = "t72 @1 v5 y0 q8 x2 l2 o3 [{df+a} {a>c+e} {b>df+} {f+a>c+} {gb>d} {df+a} {gb>d} {a>c+e}]4",
        wave = "t72 @12 v3 l2 o2 [d a b f+ g d g a]4",
    },
})
```

### Ode to Joy

Beethoven, C major at 100, as a title screen: the melody in octave 4 with its echo, a bass in halves on the `triangle` table, a soft hat on the second and fourth beats.

```lua
SpiffBoy.Tunes.register("ExampleOde", {
    title = {
        loop = true,
        pulse1 = "t100 @2 v10 y0 q7 l4 o4"
            .. " e e f g | g f e d | c c d e | e4. d8 d2"
            .. " | e e f g | g f e d | c c d e | d4. c8 c2"
            .. " | d d e c | d e8 f8 e c | d e8 f8 e d | c d <g2"
            .. " | >e e f g | g f e d | c c d e | d4. c8 c2",
        pulse2 = { echo = "pulse1", delay = 8, drop = 6 },
        wave = "t100 @0 v3 l2 o2"
            .. " c g | c g | c g | g >d<"
            .. " | c g | c g | g >d< | c g"
            .. " | g >d< | c g | g >d< | c g"
            .. " | c g | c g | g >d< | c g",
        noise = "t100 l4 [r v3 y1 n80 r n80]16",
    },
})
```

### Frère Jacques, a round in three voices

At 120: pulse 2 enters two bars after pulse 1 and the wave voice four bars after, one octave down. Each voice is the same eight bars rotated, so the loop closes on every voice at once.

```lua
SpiffBoy.Tunes.register("ExampleRound", {
    loop = {
        loop = true,
        pulse1 = "t120 @2 v11 y0 q7 l4 o4"
            .. " c d e c | c d e c | e f g2 | e f g2 | g8 a8 g8 f8 e c | g8 a8 g8 f8 e c | c <g >c2 | c <g >c2",
        pulse2 = "t120 @1 v8 y0 q7 l4 o4"
            .. " c <g >c2 | c <g >c2 | c d e c | c d e c | e f g2 | e f g2 | g8 a8 g8 f8 e c | g8 a8 g8 f8 e c",
        wave = "t120 @12 v3 l4 o3"
            .. " g8 a8 g8 f8 e c | g8 a8 g8 f8 e c | c <g >c2 | c <g >c2 | c d e c | c d e c | e f g2 | e f g2",
    },
})
```

### Toccata, as a jingle

The opening of the Toccata in D minor of Bach as a tune without loop: the two pulses in octaves, the pedal on the wave voice under the last note. Played with `play`, it ends on its own and `isPlaying()` turns false.

```lua
SpiffBoy.Tunes.register("ExampleToccata", {
    jingle = {
        pulse1 = "t80 @2 v13 y0 q8 l32 o5 a g a4. r8 l16 g f e d c+4 r8 l1 d",
        pulse2 = "t80 @2 v10 y0 q8 l32 o4 a g a4. r8 l16 g f e d c+4 r8 l1 d",
        wave = "t80 @3 v3 l4 o1 r1 r8 r16 d1",
    },
})
```

## Arrangement techniques

The techniques used by the scores above, to reuse in your own tunes.

| Technique | How to write it | In |
|---|---|---|
| Counter line | Pulse 2 follows the melody a third above, a few levels softer (`v7` under `v11`). | Carol of the Bells |
| Echo | `pulse2 = { echo = "pulse1", delay = 8, drop = 5 }` | Mountain King, Ode to Joy |
| Held chords | Pulse 2 plays chords as arpeggios in half notes, `x2`, at `v5`. | Canon in D |
| Held tones | Pulse 2 holds one chord tone per bar with `q8`. | Menuet |
| Voices entering in turn | The later voices start with rests of the length of the bars they skip. | Carol of the Bells |
| Build | The theme repeats one octave up with `@1` and a higher level; the drums enter on the repeat. | Mountain King |
| Detached or joined notes | `q6` detaches, `q7` articulates, `q8` joins. | Mountain King, Menuet |
| Plucked line | A short decay, `y3` or `y4`, on each note. | `jump`, `lose` |
| Round | The same bars on every voice, rotated, so all voices end together. | Frère Jacques |
| Bass on the wave voice | Root and fifth, `v3`, in octave 2, on `halfsine` (`@12`) or `triangle` (`@0`). | Menuet, Ode to Joy |

Back to the [README](../README.md).
