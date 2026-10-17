-- Solution of exercise 2: wrap around the edges.
-- File: lua/client/SpiffBoySDK/Games/HelloSpiffBoy/Game.lua
--
-- Replace the whole function moveSpiffo with this one.

--- Moves Spiffo by the given pixels; past an edge of the playfield he comes back on the opposite edge.
function SpiffBoySDKHelloGame:moveSpiffo(dx, dy)
    -- The positions Spiffo can take: x from 0 to width - CELL, y from
    -- PLAY_TOP to PLAY_BOTTOM - CELL. `span` is how many positions that is.
    local spanX = self.screen.width - CELL + 1
    local spanY = PLAY_BOTTOM - PLAY_TOP - CELL + 1
    -- The remainder brings a position back into 0 .. span - 1.
    -- In the Lua of the game, `%` keeps the sign of the left side:
    -- (0 - 1) % spanX would be -1, not spanX - 1. Adding spanX first keeps
    -- the left side positive, so -1 becomes spanX - 1, the right edge.
    -- This only works for a move smaller than one span, which a move of a
    -- few pixels always is.
    self.x = (self.x + dx + spanX) % spanX
    -- The playfield starts at PLAY_TOP, not 0: shift down to 0, wrap, shift back.
    self.y = (self.y - PLAY_TOP + dy + spanY) % spanY + PLAY_TOP
end
