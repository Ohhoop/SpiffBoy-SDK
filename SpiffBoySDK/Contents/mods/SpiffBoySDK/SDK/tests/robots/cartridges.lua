local ids, ticks, seed = ...

local KEYS = { "up", "down", "left", "right", "a", "b", "start" }
local CRASH_EXPECTED = {}
local PAUSE_ODDS = 300
local PAUSE_MIN_TICKS = 60
local PAUSE_SPREAD_TICKS = 240
local SAVE_WINDOW_TICKS = 600
local SAVES_PER_WINDOW = 5

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

--- Loads the definition and the game files of a game folder, and returns the error of the first file that failed to load, naming that file, or nil.
local function loadGame(folder)
    ROBOT.loadFailure = nil
    for _, part in ipairs({ "/Definition", "/Game" }) do
        local ok, problem = pcall(require, folder .. part)
        if not ok then
            return "load " .. tostring(ROBOT.loadFailure) .. ": " .. tostring(problem)
        end
    end
    return nil
end

--- Returns the error the console reports for a definition whose game class no loaded file defines.
local function missingClass(definition)
    local _, problem = pcall(SpiffBoy.GameErrors.raise, "SB-GAME-CLASS", "no game class named " .. tostring(definition.game))
    return "init: " .. tostring(problem)
end

--- Presses the buttons of the robot for one tick: a seeded random button held or tapped, or none during a pause of one to five seconds, so a save the game makes on its own meets ticks without a press; returns the next state of the generator and the ticks of pause left.
local function pressButtons(input, rng, pause)
    input:clearHeld()
    rng = (rng * 1103515245 + 12345) % 2147483648
    if pause > 0 then
        return rng, pause - 1
    end
    if rng % PAUSE_ODDS == 0 then
        return rng, PAUSE_MIN_TICKS + rng % PAUSE_SPREAD_TICKS
    end
    local key = KEYS[rng % #KEYS + 1]
    if rng % 3 == 0 then
        input:tap(key)
    else
        input.held[key] = true
    end
    return rng, 0
end

--- Returns the fields of a game that hold a number, a text or a boolean, by name.
local function plainFields(game)
    local fields = {}
    for key, value in pairs(game) do
        local kind = type(value)
        if kind == "number" or kind == "string" or kind == "boolean" then
            fields[key] = value
        end
    end
    return fields
end

--- Warns once when a field of the game holding a number, a text or a boolean differs after draw from its value before.
local function checkDrawKeepsState(before, game)
    for key, value in pairs(plainFields(game)) do
        if before[key] ~= value then
            ROBOT.warnOnce("state in draw", "draw changed self." .. tostring(key) .. " from " .. tostring(before[key]) .. " to " .. tostring(value) .. ": change the state of the game in tick only, so it plays the same on every computer (docs/10-kahlua-and-pitfalls.md, Common mistakes)")
            return
        end
    end
end

--- Returns a text that holds every key and value of a save table, its keys sorted, so two equal saves give the same text.
local function serialized(value)
    if type(value) ~= "table" then
        return type(value) .. ":" .. tostring(value)
    end
    local keys = {}
    for key, _ in pairs(value) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for i, key in ipairs(keys) do
        parts[i] = serialized(key) .. "=" .. serialized(value[key])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

--- Returns the most saves the game wrote within any span of SAVE_WINDOW_TICKS ticks, from the ticks of those saves in order.
local function busiestSaves(saveTicks)
    local busiest, first = 0, 1
    for last = 1, #saveTicks do
        while saveTicks[last] - saveTicks[first] >= SAVE_WINDOW_TICKS do
            first = first + 1
        end
        busiest = math.max(busiest, last - first + 1)
    end
    return busiest
end

--- Plays a loaded game for the ticks of the run and returns its busiest frame, its frames, its saves, its crash and the first text drawn off screen.
local function playGame(id, definition)
    local screen = SpiffBoyScreen.new(owner, 180, 120)
    screen:setPalette(SpiffBoy.Cartridges.SHADES)
    screen:setWholePixels(true)
    screen:setPlacement(0, 0, 1)
    local offScreen = ""
    local drawText = screen.text
    screen.text = function(self, str, x, ...)
        local width = SpiffBoy.PixelFont.measure(str)
        if offScreen == "" and (x < 0 or x + width > self.width) then
            offScreen = string.format("%q from x %d to %d", str, x, x + width)
        end
        return drawText(self, str, x, ...)
    end
    local runtime = SpiffBoyRuntime.new(screen)
    local chip = SpiffBoyChip.new()
    chip.listener = soundListener
    chip:boot()
    local sequencer = SpiffBoySequencer.new(chip, SpiffBoy.Tunes.set(id))
    local saves = 0
    local sameSaveTicks = {}
    local lastSave = nil
    local frames = 0
    local art = SpiffBoy.Textures.folder(definition.mod, definition.art, true)
    local drawing = false
    local context = {
        seed = seed, definition = definition, chip = chip, sequencer = sequencer, link = port, save = {},
        art = function(name)
            if drawing then
                ROBOT.warnOnce("art in draw", "art(\"" .. tostring(name) .. "\") is called in draw: load every picture once, in init (docs/03-screen-and-art.md, The art folder)")
            end
            return art(name)
        end,
        persist = function(save)
            saves = saves + 1
            local text = serialized(save)
            if text == lastSave then
                sameSaveTicks[#sameSaveTicks + 1] = frames + 1
            end
            lastSave = text
        end,
    }
    local crash = nil
    local most = 0
    local gameClass = SpiffBoy.Cartridges.resolveGame(definition)
    if gameClass and gameClass.Type ~= definition.game then
        ROBOT.warnings[#ROBOT.warnings + 1] = "class name: the global " .. definition.game .. " was made by SpiffBoyGameBase:derive(\"" .. tostring(gameClass.Type) .. "\"); give derive the same name, which the crash report prints"
    end
    if not gameClass then
        crash = missingClass(definition)
    elseif not runtime:start(gameClass, context) then
        crash = "init: " .. tostring(runtime.crash and runtime.crash.message)
    end
    runtime:setDevices({ sequencer, chip })
    local input = SpiffBoyInputState.new()
    local rng, pause = seed, 0
    for _ = 1, ticks do
        if crash then
            break
        end
        rng, pause = pressButtons(input, rng, pause)
        runtime:advance({ input }, false, 1)
        local game = runtime.game
        local before = game and plainFields(game)
        drawing = true
        runtime:draw()
        drawing = false
        if game and runtime.game == game then
            checkDrawKeepsState(before, game)
        end
        frames = frames + 1
        if screen.calls > most then
            most = screen.calls
        end
        if runtime.crash then
            crash = runtime.crash.stage .. ": " .. runtime.crash.message
        end
        flush()
    end
    local busiest = busiestSaves(sameSaveTicks)
    if busiest > SAVES_PER_WINDOW then
        ROBOT.warnings[#ROBOT.warnings + 1] = "saves: " .. busiest .. " writes within ten seconds that change nothing in the save; write it only when something changed, at the end of a game, on a SAVE entry or when the options are left (docs/05-saving.md, When to save)"
    end
    return most, frames, saves, crash or "", offScreen
end

--- Warns once for each global variable created since the given set of names whose name does not start with the namespace of the game or with SpiffBoy.
local function warnNewGlobals(before, namespace)
    for name, _ in pairs(ROBOT.globalNames()) do
        local text = tostring(name)
        if not before[name] and string.sub(text, 1, string.len(namespace)) ~= namespace and string.sub(text, 1, 8) ~= "SpiffBoy" then
            ROBOT.warnOnce("global " .. text, "global " .. text .. ": every mod shares the globals, so make it local or start its name with " .. namespace .. " (docs/02-how-a-cartridge-works.md, The game class)")
        end
    end
end

--- Loads every game folder and returns one entry per game with its id, its folder, its namespace, its load error and the warnings of its loading.
local function loadAll()
    local games = {}
    for _, folder in ipairs(ids) do
        ROBOT.warnings, ROBOT.warned = {}, {}
        local namespace = string.match(folder, "^([^/]+)/")
        local before = ROBOT.globalNames()
        local loadError = loadGame(folder)
        warnNewGlobals(before, namespace)
        games[#games + 1] = { id = string.match(folder, "([^/]+)$"), folder = folder, namespace = namespace, loadError = loadError, warnings = ROBOT.warnings, warned = ROBOT.warned }
    end
    return games
end

--- Checks the item script of every registered cartridge as the console does at the start of a game, and adds each warning to the game it names.
local function checkItems(games)
    ROBOT.warnings = {}
    SpiffBoy.Cartridges.checkItemTags()
    for _, warning in ipairs(ROBOT.warnings) do
        for _, game in ipairs(games) do
            if string.find(warning, "cartridge " .. game.id .. " of the mod ", 1, true) then
                game.warnings[#game.warnings + 1] = warning
            end
        end
    end
end

local games = loadAll()
checkItems(games)
local results = {}
for _, game in ipairs(games) do
    local id = game.id
    ROBOT.warnings, ROBOT.warned = game.warnings, game.warned
    ROBOT.beginGame(id)
    local most, frames, saves, crash, offScreen = 0, 0, 0, "", ""
    local definition = SpiffBoy.Cartridges.byId(id)
    if game.loadError then
        crash = game.loadError
    elseif not definition then
        crash = "load: the Definition.lua of " .. game.folder .. " registers no cartridge with the id " .. id
    else
        local before = ROBOT.globalNames()
        most, frames, saves, crash, offScreen = playGame(id, definition)
        warnNewGlobals(before, game.namespace)
    end
    results[#results + 1] = {
        id = id, most = most, frames = frames, saves = saves, crash = crash, offScreen = offScreen,
        warnings = table.concat(ROBOT.warnings, " | "), expected = CRASH_EXPECTED[id] == true, digest = ROBOT.endGame(),
    }
end
return results
