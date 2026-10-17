-- Solution of exercise 7: a pause screen.
-- Files: lua/shared/SpiffBoySDK/Games/HelloSpiffBoy/Translate/EN.json
--        lua/client/SpiffBoySDK/Games/HelloSpiffBoy/Game.lua
--
-- This is an excerpt, not a file to load: copy each part over the matching
-- part of the files.

-- Part 1, EN.json: add a key inside the "UI" section.
--
--     "Paused": "PAUSED",

-- Part 2, Game.lua: at the end of enterPlay, every visit starts unpaused.
    self.paused = false

-- Part 3, Game.lua: in tickPlay, replace the block
--     if pressed.start then
--         self:leavePlay()
--         return
--     end
-- with this one.
    if self.paused then
        self:tickPause(pressed)
        -- Nothing else moves while paused: leave tickPlay at once.
        return
    end
    if pressed.start then
        self.paused = true
        self.sequencer:stop()
        return
    end

-- Part 4, Game.lua: a new method, under tickPlay.

--- Resumes the play on START, or goes back to the title on B.
function SpiffBoySDKHelloGame:tickPause(pressed)
    if pressed.start then
        self.paused = false
        -- applyMusic follows the music option: the theme starts again from
        -- its beginning when the music is on, and stays silent when it is off.
        self:applyMusic()
    elseif pressed.b then
        self.paused = false
        -- The title screen plays the theme too.
        self:applyMusic()
        self:leavePlay()
    end
end

-- Part 5, Game.lua: at the end of drawPlay, draw the box over everything else.
    if self.paused then
        self:drawPause(screen)
    end

-- Part 6, Game.lua: a new method, under drawBubble.

--- Draws the word PAUSED in a box in the middle of the playfield.
function SpiffBoySDKHelloGame:drawPause(screen)
    local text = gameText("Paused")
    local w = screen:textWidth(text) + 12
    local h = screen:lineHeight() + 4
    local x = math.floor((screen.width - w) / 2)
    local y = math.floor((PLAY_TOP + PLAY_BOTTOM - h) / 2)
    -- The same one pixel border as the bubble: a dark box, a light inside.
    screen:rect(x, y, w, h, ink(1))
    screen:rect(x + 1, y + 1, w - 2, h - 2, ink(4))
    screen:textCentre(text, math.floor(screen.width / 2), y + 2, ink(1))
end
