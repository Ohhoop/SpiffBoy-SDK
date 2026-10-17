-- Solution of exercise 1: change the speed of Spiffo.
-- File: lua/client/SpiffBoySDK/Games/HelloSpiffBoy/Game.lua
--
-- This is an excerpt, not a file to load: copy each part over the matching
-- part of Game.lua.

-- Part 1, near the top of Game.lua: replace the constant SPEED.
-- tick runs 60 times per second, so 2 pixels per tick is 120 pixels per
-- second, two thirds of the 180 pixel wide screen.
local SPEED = 2

-- Going further: run while A is held.
-- Replace the two lines of tickPlay that read the arrows and move Spiffo
-- with the lines below.

    local dx, dy = input:axes()
    -- `held` stays true for every tick the button is down, so this works for
    -- as long as A is held. `pressed` would be true for one tick only.
    local speed = SPEED
    if input.held.a then
        speed = SPEED * 2
    end
    self:moveSpiffo(dx * speed, dy * speed)

-- A speed below 1, such as 0.5, also works: the position keeps its
-- fraction, and the screen takes it down to the whole pixel when drawing,
-- so Spiffo moves one pixel every other tick.
