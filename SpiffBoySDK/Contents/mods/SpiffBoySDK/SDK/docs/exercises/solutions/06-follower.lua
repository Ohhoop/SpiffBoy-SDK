-- Solution of exercise 6: a second sprite that follows.
-- File: lua/client/SpiffBoySDK/Games/HelloSpiffBoy/Game.lua
--
-- This is an excerpt, not a file to load: copy each part over the matching
-- part of Game.lua.

-- Part 1, near the top, under the other constants.
-- The buddy is drawn in two shades only, so it looks paler than Spiffo and
-- costs two draw calls instead of three.
local BUDDY_SHADES = { 1, 2 }
-- The buddy stops when it is this close to Spiffo on both axes.
local BUDDY_GAP = CELL + 2

-- Part 2, under the function clamp.

--- Returns 1 for a positive number, -1 for a negative one and 0 for zero.
local function sign(value)
    if value > 0 then
        return 1
    end
    if value < 0 then
        return -1
    end
    return 0
end

-- Part 3, at the end of enterPlay: the buddy starts on the left of Spiffo.
    self.buddyX = self.x - BUDDY_GAP
    self.buddyY = self.y

-- Part 4, at the end of tickPlay:
    self:moveBuddy()

-- Part 5, a new method, under moveSpiffo.

--- Moves the buddy one pixel toward Spiffo every other tick while it is farther than one head away.
function SpiffBoySDKHelloGame:moveBuddy()
    -- Every other tick: the buddy moves at 30 pixels per second, half the
    -- speed of Spiffo. self.ticks only grows, so `%` is safe here.
    if self.ticks % 2 ~= 0 then
        return
    end
    local dx = self.x - self.buddyX
    local dy = self.y - self.buddyY
    if math.abs(dx) <= BUDDY_GAP and math.abs(dy) <= BUDDY_GAP then
        return
    end
    self.buddyX = self.buddyX + sign(dx)
    self.buddyY = self.buddyY + sign(dy)
end

-- Part 6, in drawPlay, just before the line that draws Spiffo.
-- Drawn first, the buddy stays behind Spiffo when they overlap.
-- The blinking cell gives the buddy shut eyes: it walks in its sleep.
    screen:layers(self.spiffo, FRAME_BLINK * CELL, CELL, CELL, self.buddyX, self.buddyY, BUDDY_SHADES)
