-- Solution of exercise 4: a different effect every tenth hello.
-- Files: lua/client/SpiffBoySDK/Games/HelloSpiffBoy/Music.lua
--        lua/client/SpiffBoySDK/Games/HelloSpiffBoy/Game.lua
--
-- This is an excerpt, not a file to load: copy each part over the matching
-- part of the files.

-- Part 1, Music.lua: add the name of the effect with the other names.
Music.CHEER = "cheer"

-- Part 2, Music.lua: add the tune inside SpiffBoy.Tunes.register, next to
-- the other effects.
--
-- `t240` a fast tempo, `@2` half duty (a full, round square), `v12` loud,
-- `y1` each note fades quickly, `l32` thirty-second notes by default,
-- `o5` octave 5. The notes climb a C major chord over two octaves.
-- It uses pulse2, the voice the theme leaves free, so the melody goes on.
    [Music.CHEER] = { pulse2 = "t240 @2 v12 y1 l32 o5 c e g >c e g >c8" },

-- Part 3, Game.lua: in sayHello, replace the line
--     self.sequencer:effect(Music.HELLO)
-- with:
    -- The count is never negative, so `%` gives 0 exactly on 10, 20, 30...
    if self.count % 10 == 0 then
        self.sequencer:effect(Music.CHEER)
    else
        self.sequencer:effect(Music.HELLO)
    end

-- A name that was never registered is an error in the sequencer, so a typing
-- mistake such as Music.CHEEER (nil) or "cheeer" stops the game at once
-- and the robot reports it as a crash. That is on purpose: a silent mistake
-- is harder to find than a loud one.
