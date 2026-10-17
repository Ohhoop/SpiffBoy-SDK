-- The best scores of Spiff-Pong and how they live in the save of the cartridge.
--
-- SAVE AND PERSIST
-- self.save is a plain table the framework loads from the cartridge item when
-- the game starts. The game writes into it, then calls self:persist() to
-- store it back on the cartridge, which carries it from console to console.
-- The save keeps string and whole number keys, numbers, strings, booleans and
-- nested tables, up to 6 levels and 512 entries; a string longer than 128
-- characters is cut, and a key longer than 32 characters is dropped with its
-- value.
--
-- Never trust what comes out of a save: an older version of the game, another
-- mod or a hand edit may have left anything there. read() checks every value
-- and keeps only what it understands; write() turns the clean records back
-- into the save form.
--
-- What is kept:
--   * the five longest rallies against the console, each as a short text
--     "ABC:12" (initials and number of hits);
--   * the number of matches won and lost against the console.

require "SpiffBoySDK/Core"

SpiffBoySDK.SpiffPong = SpiffBoySDK.SpiffPong or {}

local Records = {}
SpiffBoySDK.SpiffPong.Records = Records

Records.SIZE = 5
Records.INITIALS_LENGTH = 3
Records.LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

local ENTRY_PATTERN = "^([A-Z0-9][A-Z0-9][A-Z0-9]):(%d+)$"
local MAX_DIGITS = 6
local MAX_COUNT = 999999

--- Returns a saved counter as a whole number from 0 to its maximum, 0 when the save holds anything else.
local function readCount(value)
    if type(value) ~= "number" or value ~= math.floor(value) or value < 0 then
        return 0
    end
    return math.min(value, MAX_COUNT)
end

--- Returns the best scores held by the save: the list of the longest rallies, best first, and the counts of wins and losses.
function Records.read(save)
    local records = { rallies = {}, wins = 0, losses = 0 }
    local saved = save.records
    if type(saved) ~= "table" then
        return records
    end
    records.wins = readCount(saved.wins)
    records.losses = readCount(saved.losses)
    if type(saved.rallies) == "table" then
        for i = 1, Records.SIZE do
            local entry = saved.rallies[i]
            if type(entry) == "string" then
                local initials, digits = string.match(entry, ENTRY_PATTERN)
                if initials and string.len(digits) <= MAX_DIGITS then
                    records.rallies[#records.rallies + 1] = { initials = initials, rally = tonumber(digits) }
                end
            end
        end
    end
    return records
end

--- Writes the best scores into the save in the form it keeps them.
function Records.write(save, records)
    local rallies = {}
    for i = 1, #records.rallies do
        local entry = records.rallies[i]
        rallies[i] = entry.initials .. ":" .. tostring(entry.rally)
    end
    save.records = { rallies = rallies, wins = records.wins, losses = records.losses }
end

--- Returns the rank a rally would take in the list of the longest rallies, or nil when it does not enter.
function Records.rankOf(records, rally)
    if rally <= 0 then
        return nil
    end
    local list = records.rallies
    for i = 1, #list do
        if rally > list[i].rally then
            return i
        end
    end
    if #list < Records.SIZE then
        return #list + 1
    end
    return nil
end

--- Inserts a rally with its initials at its rank, dropping the entry pushed past the end; returns the rank, or nil when the rally does not enter.
function Records.insert(records, initials, rally)
    local rank = Records.rankOf(records, rally)
    if not rank then
        return nil
    end
    table.insert(records.rallies, rank, { initials = initials, rally = math.min(rally, MAX_COUNT) })
    while #records.rallies > Records.SIZE do
        table.remove(records.rallies)
    end
    return rank
end

--- Counts one more match won or lost against the console.
function Records.count(records, won)
    if won then
        records.wins = math.min(records.wins + 1, MAX_COUNT)
    else
        records.losses = math.min(records.losses + 1, MAX_COUNT)
    end
end
