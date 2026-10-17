-- The music and sound effects of Spiff-Pong, written for the sound chip.
--
-- A cartridge ships notes, never audio files. Each tune gives a string of
-- music notation per voice of the chip it uses (pulse1, pulse2, wave, noise),
-- see docs/04-sound-and-music.md of the SDK. They are registered once, when this file loads, under the
-- id of the cartridge, so the computers of the players nearby, which replay
-- the console on their own copy of the chip, find them too.
--
-- TUNES VS EFFECTS
--   * self.sequencer:play(name) plays a tune as THE music: one at a time, it
--     replaces the previous music, and `loop = true` makes it repeat.
--   * self.sequencer:effect(name) plays a tune once on top of the music: it
--     borrows the voices it uses and gives them back when it ends.
-- The options switch the music off with setMix(0, 1) while the effects stay.
--
-- Like the arcade original, the match itself has no music: only the blips of
-- the ball. Music plays on the menus, at the start and at the end of a match.

require "SpiffBoySDK/Core"
require "SpiffBoy/Core/Tunes"

SpiffBoySDK.SpiffPong = SpiffBoySDK.SpiffPong or {}

local Music = {}
SpiffBoySDK.SpiffPong.Music = Music

-- Names of the tunes, used by the game instead of bare strings.
Music.TITLE = "title"
Music.START = "start"
Music.WIN = "win"
Music.LOSE = "lose"
Music.PADDLE = "paddle"
Music.WALL = "wall"
Music.POINT = "point"
Music.MOVE = "move"
Music.CONFIRM = "confirm"
Music.BACK = "back"
Music.REFUSE = "refuse"
Music.PAUSE = "pause"

-- One bar of drums in eighths: kick, hat, snare, hat, kick, kick, snare, hat.
local KICK = "v9 y1 n{40 88 113}"
local HAT = "v2 y1 n88"
local SNARE = "v6 y2 n{48 72}"
local BAR = KICK .. " " .. HAT .. " " .. SNARE .. " " .. HAT .. " " .. KICK .. " " .. KICK .. " " .. SNARE .. " " .. HAT

SpiffBoy.Tunes.register("SpiffPong", {
    -- The title music: an eight bar loop in G major.
    [Music.TITLE] = {
        loop = true,
        pulse1 = "t132 @2 v11 y1 q6 l8 o5"
            .. " d r d g r b a g | e r e a r g f+ e | d r d g r b a g | a b a g f+4 g4"
            .. " | b r b >d< r b a g | a r a >c< r a g f+ | g r b r a r f+ r | g2 r2",
        pulse2 = "t132 @1 v5 y0 q5 l4 x2 o4"
            .. " {gb>d} {gb>d} {gb>d} {gb>d} | {a>ce} {a>ce} {a>ce} {a>ce} | {gb>d} {gb>d} {gb>d} {gb>d} | {df+a} {df+a} {df+a} {df+a}"
            .. " | {gb>d} {gb>d} {gb>d} {gb>d} | {a>ce} {a>ce} {a>ce} {a>ce} | {df+a} {df+a} {df+a} {df+a} | {gb>d} {gb>d} {gb>d} {gb>d}",
        wave = "t132 @5 v3 l4 o2"
            .. " g >d< g >d< | a >e< a >e< | g >d< g >d< | d a d a"
            .. " | g >d< g >d< | a >e< a >e< | d a d a | g >d< g2",
        noise = "t132 l8 [" .. BAR .. "]8",
    },
    -- Played as the music when a match begins, then silence for the match.
    [Music.START] = {
        pulse1 = "t176 @2 v11 y1 q7 l16 o5 g r g r >d8< b8 >g4",
        pulse2 = "t176 @1 v7 y1 q7 l16 o4 b r b r >g8< g8 >b4",
        wave = "t176 @5 v3 l8 o2 g g >d< g4",
    },
    [Music.WIN] = {
        pulse1 = "t160 @2 v12 y1 q7 l16 o5 c e g >c< g >c e8 d8 e8 g4",
        pulse2 = "t160 @1 v7 y1 q7 l16 o4 g >c e g e g >c8< b8 >c8 e4",
        wave = "t160 @5 v3 l8 o2 c >c< g >c< f g c4",
        noise = "t160 l8 " .. KICK .. " " .. HAT .. " " .. SNARE .. " " .. HAT .. " " .. KICK .. " " .. SNARE .. " " .. KICK,
    },
    [Music.LOSE] = {
        pulse1 = "t96 @2 v10 y0 q7 l8 o5 e d c o4 b a4 g+4 a2",
        pulse2 = "t96 @1 v6 y0 q7 l8 o4 c o3 b a g+ e4 e4 e2",
        wave = "t96 @12 v3 l4 o2 a e f e a2",
    },
    -- The blips of the ball: a high square for a paddle, a lower one for a wall.
    [Music.PADDLE] = { pulse2 = "t240 @2 v12 y2 l32 o5 b" },
    [Music.WALL] = { pulse2 = "t240 @2 v9 y2 l32 o4 b" },
    [Music.POINT] = { pulse1 = "t150 @2 v12 y3 s2,-3 l8 o4 d", noise = "t150 l16 v6 y2 n{56 104}" },
    [Music.MOVE] = { pulse2 = "t240 @1 v6 y2 l32 o6 d" },
    [Music.CONFIRM] = { pulse2 = "t230 @2 v9 y2 l32 o5 d g >d" },
    [Music.BACK] = { pulse2 = "t230 @2 v8 y2 l32 o5 g d" },
    [Music.REFUSE] = { pulse2 = "t200 @3 v8 y2 l32 o3 f f" },
    [Music.PAUSE] = { pulse2 = "t210 @1 v9 y2 l32 o5 a e" },
})
