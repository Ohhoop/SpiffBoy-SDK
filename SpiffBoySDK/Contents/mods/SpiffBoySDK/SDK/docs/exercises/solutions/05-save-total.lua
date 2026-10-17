-- Solution of exercise 5: save a new value.
-- Files: lua/shared/SpiffBoySDK/Games/HelloSpiffBoy/Translate/EN.json
--        lua/client/SpiffBoySDK/Games/HelloSpiffBoy/Game.lua
--
-- This is an excerpt, not a file to load: copy each part over the matching
-- part of the files.

-- Part 1, EN.json: add a key inside the "UI" section.
--
--     "Total": "TOTAL %1",
--
-- %1 is replaced by the first argument given to gameText.

-- Part 2, Game.lua: add this function under readBest.

--- Returns the total of hellos held by the save, or 0 when the save holds none.
local function readTotal(save)
    -- A cartridge saved before this exercise has no `total`. A value of the
    -- wrong type can only come from a broken save: start again from 0.
    local total = save.total
    if type(total) ~= "number" or total < 0 then
        return 0
    end
    return math.floor(total)
end

-- Part 3, Game.lua: in init, under the line that reads the best count, add:
    self.total = readTotal(self.save)

-- Part 4, Game.lua: replace the whole function leavePlay.

--- Writes a new best count and the new total in the save, then goes back to the title screen.
function SpiffBoySDKHelloGame:leavePlay()
    local changed = false
    if self.best ~= self.save.best then
        self.save.best = self.best
        changed = true
    end
    if self.count > 0 then
        self.total = self.total + self.count
        self.save.total = self.total
        changed = true
    end
    -- One persist for both values: each call writes the cartridge item and,
    -- in multiplayer, sends it to the server.
    if changed then
        self:persist()
    end
    self:enterTitle()
end

-- Part 5, Game.lua: in drawTitle, replace the last line, the one drawing
-- gameText("Best", self.best), with these lines.
    -- The title has no free line: show the best count and the total in
    -- turns, two seconds each, as the hint of the play screen does.
    local record = gameText("Best", self.best)
    if math.floor(self.ticks / HINT_TICKS) % 2 == 1 then
        record = gameText("Total", self.total)
    end
    screen:textCentre(record, centre, 100, ink(2))
