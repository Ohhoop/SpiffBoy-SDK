-- The tunes of Hello SpiffBoy.
--
-- A cartridge ships no audio file. It ships notes, written in the music
-- notation of the console (see SDK/docs/14-sound-chip-reference.md), and the
-- sound chip of the console plays them. This is why the other players around the
-- character hear the game: their own computer replays the same notes on a
-- copy of the chip, so only "play the tune theme" travels on the network.
--
-- The chip has four voices: two pulse voices (square waves), a wave voice
-- (a small table of samples, used here for the bass) and a noise voice
-- (used for drums). A tune gives one string per voice it uses.
--
-- A tune is played in one of two ways by the sequencer of the console:
--   self.sequencer:play(name)    plays it as the music, looping when `loop = true`.
--   self.sequencer:effect(name)  plays it once as a sound effect. An effect
--                                borrows its voices from the music and gives
--                                them back when it ends.
-- The theme below leaves the second pulse voice free, so the short effects,
-- which all use pulse2, never cut the melody.

require "SpiffBoySDK/Core"
require "SpiffBoy/Core/Tunes"

SpiffBoySDK.HelloSpiffBoy = SpiffBoySDK.HelloSpiffBoy or {}

local Music = {}
SpiffBoySDK.HelloSpiffBoy.Music = Music

-- The names of the tunes, kept in one place so Game.lua and the register call
-- below always spell them the same way. Playing a name that was not
-- registered raises an error in the sequencer, which stops the game.
Music.THEME = "theme"
Music.HELLO = "hello"
Music.MOVE = "move"
Music.SELECT = "select"
Music.TOGGLE = "toggle"
-- Exercise 4: add the name of your new effect here, such as Music.CHEER = "cheer".

-- The tunes are registered once, when this file loads, under the id of the
-- cartridge. The console looks the tunes of a cartridge up by that id, also
-- on the computers of the players who only hear the console.
SpiffBoy.Tunes.register("HelloSpiffBoy", {
    -- The music: a four bar loop in C major at 120 beats per minute.
    -- `t` tempo, `@` timbre (duty of the pulse), `v` level, `y0` no decay,
    -- `q6` holds each note for 6 eighths of its length, `l8` eighth notes by
    -- default, `o5` octave 5. The `|` only separate the bars for the reader.
    [Music.THEME] = {
        loop = true,
        pulse1 = "t120 @1 v10 y0 q6 l8 o5"
            .. " c e g e f a g4 | e g >c< g f d e4"
            .. " | c e g e f a g4 | a f e d c4 r4",
        -- The bass on the wave voice: `@11` picks the `round` wave table and
        -- `v2` is half level (the wave voice has only levels 0 to 3).
        wave = "t120 @11 v2 l4 o3 c g f g | c g g c | c g f g | f g c r",
        -- Light drums on the noise voice: `n<value>` plays a noise setting,
        -- `n{40 72 113}` steps through three settings to sound like a kick,
        -- `n32` is a soft hiss for the hat. `[ ... ]4` repeats the bar four times.
        noise = "t120 l8 [v9 y1 n{40 72 113} r v4 y1 n32 r v7 y2 n56 r v4 y1 n32 r]4",
    },
    -- The effect of A: a rising "hel-lo" of two notes.
    [Music.HELLO] = { pulse2 = "t200 @2 v12 y2 l16 o5 g >e8" },
    -- The tick of the cursor moving in the menu.
    [Music.MOVE] = { pulse2 = "t240 @3 v8 y1 l32 o6 c" },
    -- The chime of PLAY chosen in the menu.
    [Music.SELECT] = { pulse2 = "t220 @2 v11 y1 l32 o5 c g >c" },
    -- The blip of the music switched on or off.
    [Music.TOGGLE] = { pulse2 = "t240 @1 v10 y1 l32 o5 e <e" },
    -- Exercise 4: add your new effect here, for example
    -- [Music.CHEER] = { pulse2 = "t240 @2 v12 y1 l32 o5 c e g >c e g" },
})
