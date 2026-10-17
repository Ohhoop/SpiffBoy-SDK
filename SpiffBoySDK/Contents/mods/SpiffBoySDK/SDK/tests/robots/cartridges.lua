local ids, ticks, seed = ...

local KEYS = { "up", "down", "left", "right", "a", "b", "start" }
local CRASH_EXPECTED = {}

local buffer, size = {}, 0
local function record(...)
    local args = { ... }
    for i = 1, select("#", ...) do
        local value = args[i]
        if type(value) == "table" then
            value = value.path
        end
        size = size + 1
        buffer[size] = tostring(value)
    end
end

local owner = {
    drawRect = function(_, ...) record("R", ...) end,
    drawSubTexture = function(_, ...) record("S", ...) end,
    drawTextureScaled = function(_, ...) record("T", ...) end,
    drawTextureAllPoint = function(_, ...) record("P", ...) end,
    setStencilRect = function() end,
    clearStencilRect = function() end,
}

local soundListener = {
    onChipWrite = function(_, register, value) record("W", register, value) end,
    onChipWave = function(_, name) record("V", name) end,
}

local port = {
    isConnected = function() return false end,
    seat = function() return nil end,
    send = function() return false end,
    receive = function() return nil end,
}

local function flush()
    if size > 0 then
        ROBOT.digest(table.concat(buffer, ",", 1, size))
        size = 0
    end
end

local results = {}
for _, id in ipairs(ids) do
    local folder = id
    id = string.match(folder, "([^/]+)$")
    require(folder .. "/Definition")
    require(folder .. "/Game")
    local definition = SpiffBoy.Cartridges.byId(id)
    local gameClass = SpiffBoy.Cartridges.resolveGame(definition)
    local screen = SpiffBoyScreen.new(owner, 180, 120)
    screen:setPalette(SpiffBoy.Cartridges.SHADES)
    screen:setWholePixels(true)
    screen:setPlacement(0, 0, 1)
    local runtime = SpiffBoyRuntime.new(screen)
    local chip = SpiffBoyChip.new()
    chip.listener = soundListener
    chip:boot()
    local sequencer = SpiffBoySequencer.new(chip, SpiffBoy.Tunes.set(id))
    local saves = 0
    local context = {
        seed = seed, definition = definition, art = function(name) return ROBOT.texture(id .. "/" .. name) end,
        chip = chip, sequencer = sequencer, link = port, save = {},
        persist = function() saves = saves + 1 end,
    }
    ROBOT.beginGame(id)
    local crash = nil
    local most, frames = 0, 0
    if not runtime:start(gameClass, context) then
        crash = "init: " .. tostring(runtime.crash and runtime.crash.message)
    end
    runtime:setDevices({ sequencer, chip })
    local input = SpiffBoyInputState.new()
    local rng = seed
    for _ = 1, ticks do
        if crash then
            break
        end
        input:clearHeld()
        rng = (rng * 1103515245 + 12345) % 2147483648
        local key = KEYS[rng % #KEYS + 1]
        if rng % 3 == 0 then
            input:tap(key)
        else
            input.held[key] = true
        end
        runtime:advance({ input }, false, 1)
        runtime:draw()
        frames = frames + 1
        if screen.calls > most then
            most = screen.calls
        end
        if runtime.crash then
            crash = runtime.crash.stage .. ": " .. runtime.crash.message
        end
        flush()
    end
    results[#results + 1] = {
        id = id, most = most, frames = frames, saves = saves, crash = crash or "",
        expected = CRASH_EXPECTED[id] == true, digest = ROBOT.endGame(),
    }
end
return results
