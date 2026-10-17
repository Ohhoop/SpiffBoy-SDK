-- The options of Spiff-Pong: music on or off, the speed of the ball and the
-- points to win. They are part of the save, read with the same care as the
-- best scores, and written only when the player leaves the options screen
-- after changing something, so the cartridge is not rewritten for nothing.

require "SpiffBoySDK/Core"
require "SpiffBoySDK/Games/SpiffPong/Match"

SpiffBoySDK.SpiffPong = SpiffBoySDK.SpiffPong or {}

local Match = SpiffBoySDK.SpiffPong.Match

local Options = {}
SpiffBoySDK.SpiffPong.Options = Options

-- The entries of the options screen, in order. `texts` names the text of each
-- value; the music entry is a switch.
Options.ENTRIES = {
    { key = "music", text = "Music" },
    { key = "speed", text = "Speed", texts = { "Slow", "Normal", "Fast" } },
    { key = "points", text = "Points", values = Match.POINTS },
}

Options.DEFAULTS = { music = true, speed = 2, points = 2 }

--- Returns true when the value is a whole number from 1 to the given count.
local function isIndex(value, count)
    return type(value) == "number" and value == math.floor(value) and value >= 1 and value <= count
end

--- Returns the options held by the save, each one checked, the default kept where the save holds nothing valid.
function Options.read(save)
    local options = { music = Options.DEFAULTS.music, speed = Options.DEFAULTS.speed, points = Options.DEFAULTS.points }
    local saved = save.options
    if type(saved) ~= "table" then
        return options
    end
    if type(saved.music) == "boolean" then
        options.music = saved.music
    end
    if isIndex(saved.speed, #Match.SPEEDS) then
        options.speed = saved.speed
    end
    if isIndex(saved.points, #Match.POINTS) then
        options.points = saved.points
    end
    return options
end

--- Writes the options into the save.
function Options.write(save, options)
    save.options = { music = options.music, speed = options.speed, points = options.points }
end

--- Turns the given entry of the options one step in the given direction, wrapping around.
function Options.turn(options, entry, step)
    if entry.key == "music" then
        options.music = not options.music
        return
    end
    local count = #Match.SPEEDS
    if entry.key == "points" then
        count = #Match.POINTS
    end
    -- Wrap a value that can go below 1 without relying on % with a negative
    -- number, which truncates toward zero in Kahlua: (value - 1 + count) stays positive.
    options[entry.key] = (options[entry.key] - 1 + step + count) % count + 1
end
