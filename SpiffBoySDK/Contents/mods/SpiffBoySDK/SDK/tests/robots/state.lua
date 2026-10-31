require "SpiffBoy/Core/SaveState"

local STATE = {}

local KEYS = { "up", "down", "left", "right", "a", "b", "start" }

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

--- Sends what was drawn and played since the last call to the digest of the game.
local function flush()
    if size > 0 then
        ROBOT.digest(table.concat(buffer, ",", 1, size))
        size = 0
    end
end

--- Builds the parts of a console running the cartridge of the given game folder: screen, runtime, chip, sequencer and the context of its game, with the art loader that names its textures.
local function partsOf(folder, seed)
    require(folder .. "/Definition")
    require(folder .. "/Game")
    local id = string.match(folder, "([^/]+)$")
    local definition = SpiffBoy.Cartridges.byId(id)
    local screen = SpiffBoyScreen.new(owner, 180, 120)
    screen:setPalette(SpiffBoy.Cartridges.SHADES)
    screen:setWholePixels(true)
    screen:setPlacement(0, 0, 1)
    local runtime = SpiffBoyRuntime.new(screen)
    local chip = SpiffBoyChip.new()
    chip.listener = soundListener
    chip:boot()
    local sequencer = SpiffBoySequencer.new(chip, SpiffBoy.Tunes.set(id))
    local artNames = {}
    local context = {
        seed = seed, definition = definition,
        art = SpiffBoy.SaveState.namedArt(SpiffBoy.Textures.folder(definition.mod, definition.art, true), artNames),
        chip = chip, sequencer = sequencer, link = port, save = {},
        persist = function() end,
    }
    return { id = id, screen = screen, runtime = runtime, chip = chip, sequencer = sequencer, context = context, artNames = artNames, definition = definition }
end

--- Starts the game of the cartridge of the given game folder from power on, or returns nil when its game does not start.
function STATE.start(folder, seed)
    local console = partsOf(folder, seed)
    if not console.runtime:start(SpiffBoy.Cartridges.resolveGame(console.definition), console.context) then
        return nil
    end
    console.runtime:setDevices({ console.sequencer, console.chip })
    return console
end

--- Plays the given number of ticks with the buttons the generator draws from the given number, and returns the next number of the generator and the crash, if any.
function STATE.play(console, ticks, rng)
    local input = SpiffBoyInputState.new()
    for _ = 1, ticks do
        input:clearHeld()
        rng = (rng * 1103515245 + 12345) % 2147483648
        local key = KEYS[rng % #KEYS + 1]
        if rng % 3 == 0 then
            input:tap(key)
        else
            input.held[key] = true
        end
        console.runtime:advance({ input }, false, 1)
        console.runtime:draw()
        if console.runtime.crash then
            flush()
            return rng, console.runtime.crash.stage .. ": " .. console.runtime.crash.message
        end
        flush()
    end
    return rng, nil
end

--- Returns the parts a save state is taken from or put into.
local function stateParts(console)
    return {
        runtime = console.runtime, chip = console.chip, sequencer = console.sequencer,
        context = console.context, artNames = console.artNames, game = console.runtime.game,
    }
end

--- Freezes the console into a save state.
function STATE.capture(console)
    return SpiffBoy.SaveState.capture(stateParts(console), SpiffBoy.SaveState.NO_PACE)
end

--- Builds a console of the cartridge of the given game folder from a save state.
function STATE.restore(folder, seed, data)
    local console = partsOf(folder, seed)
    local parts = stateParts(console)
    parts.game = nil
    SpiffBoy.SaveState.restore(data, parts, SpiffBoy.SaveState.NO_PACE)
    console.runtime:setDevices({ console.sequencer, console.chip })
    return console
end

--- Runs the given number of ticks with no button held, the chip writing down what it plays, then returns the fingerprint of the state reached and of those writes, as the console does before and after a handover.
function STATE.fingerprintAhead(console, ticks)
    local trace = {}
    console.chip.listener = SpiffBoy.SaveState.chipTrace(trace)
    console.runtime:stepTicks({ SpiffBoyInputState.new() }, ticks)
    console.chip.listener = soundListener
    return SpiffBoy.SaveState.fingerprint(STATE.capture(console), trace, SpiffBoy.SaveState.NO_PACE)
end

--- Returns the number of tables a save state holds.
function STATE.size(data)
    return SpiffBoy.listCount(data.nodes)
end

return STATE
