-- A console for tests of your own: it starts one cartridge offline on top of
-- the real code of SpiffBoy and plays it with the buttons your test chooses,
-- through the same runtime as the game, so every rule of the console applies:
-- the views, the save only on a press, the draw call limit, the errors.
--
-- tests/run_test.py loads this file before your test, which then reads:
--
--   local console = TestConsole.start("MyMod/Games/SpaceRace", 7, {})
--   console:press("a")            -- one tick with A pressed
--   console:hold(30, "up")        -- 30 ticks with up held
--   console:wait(60)              -- 60 ticks without any button
--   TestConsole.check(console.game.score > 0, "the race scores")
--
-- console.game is your game object: a test may read its fields, such as the
-- score or the screen it shows, to decide what to press next.

TestConsole = { checks = 0, failures = 0 }
TestConsole.__index = TestConsole

local OWNER = {
    drawRect = function() end,
    drawSubTexture = function() end,
    drawTextureScaled = function() end,
    drawTextureAllPoint = function() end,
    setStencilRect = function() end,
    clearStencilRect = function() end,
}

local UNPLUGGED = {
    isConnected = function() return false end,
    seat = function() return nil end,
    send = function() return false end,
    receive = function() return nil end,
}

local BUTTONS = {}
for _, key in ipairs(SpiffBoy.Input.ACTIONS) do
    BUTTONS[key] = true
end

--- Returns a copy of a save table and of the tables it holds.
local function copyOf(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = copyOf(inner)
    end
    return copy
end

--- Raises an error naming every key that is not a button of the console.
local function checkButtons(keys)
    for _, key in ipairs(keys) do
        if not BUTTONS[key] then
            error("TestConsole: " .. tostring(key) .. " is no button of the console; the buttons are up, down, left, right, a, b and start", 3)
        end
    end
end

--- Starts the cartridge of the given game folder, such as "MyMod/Games/SpaceRace", with the given seed and save table, and returns the console playing it: its game in console.game, the saves written in console.saves, the busiest frame in console.most, and the crash, if any, in console.crash.
function TestConsole.start(folder, seed, save)
    require(folder .. "/Definition")
    require(folder .. "/Game")
    local id = string.match(folder, "([^/]+)$")
    local definition = SpiffBoy.Cartridges.byId(id)
    if not definition then
        error("TestConsole: the Definition.lua of " .. folder .. " registers no cartridge with the id " .. id, 2)
    end
    local gameClass = SpiffBoy.Cartridges.resolveGame(definition)
    if not gameClass then
        error("TestConsole: no game class named " .. tostring(definition.game), 2)
    end
    local console = setmetatable({ saves = {}, crash = nil, most = 0, ticks = 0 }, TestConsole)
    local screen = SpiffBoyScreen.new(OWNER, 180, 120)
    screen:setPalette(SpiffBoy.Cartridges.SHADES)
    screen:setWholePixels(true)
    screen:setPlacement(0, 0, 1)
    local chip = SpiffBoyChip.new()
    chip:boot()
    local sequencer = SpiffBoySequencer.new(chip, SpiffBoy.Tunes.set(id))
    local context = {
        seed = seed, definition = definition, art = SpiffBoy.Textures.folder(definition.mod, definition.art, true),
        chip = chip, sequencer = sequencer, link = UNPLUGGED, save = save,
        persist = function(written)
            console.saves[#console.saves + 1] = copyOf(written)
        end,
    }
    console.screen = screen
    console.runtime = SpiffBoyRuntime.new(screen)
    if not console.runtime:start(gameClass, context) then
        console.crash = "init: " .. tostring(console.runtime.crash and console.runtime.crash.message)
    end
    console.runtime:setDevices({ sequencer, chip })
    console.input = SpiffBoyInputState.new()
    console.game = console.runtime.game
    return console
end

--- Plays one tick with the given buttons held and the given buttons pressed, then draws a frame; returns false once the game has crashed.
function TestConsole:step(held, pressed)
    checkButtons(held)
    checkButtons(pressed)
    if self.crash then
        return false
    end
    local input = self.input
    input:clearHeld()
    for _, key in ipairs(held) do
        input.held[key] = true
    end
    for _, key in ipairs(pressed) do
        input:tap(key)
    end
    self.runtime:advance({ input }, false, 1)
    self.runtime:draw()
    self.ticks = self.ticks + 1
    if self.screen.calls > self.most then
        self.most = self.screen.calls
    end
    if self.runtime.crash then
        self.crash = self.runtime.crash.stage .. ": " .. self.runtime.crash.message
    end
    return self.crash == nil
end

--- Plays one tick with the given buttons pressed, a short press each; returns false once the game has crashed.
function TestConsole:press(...)
    return self:step({}, { ... })
end

--- Plays the given number of ticks with the given buttons held down; the first tick counts as their press. Returns false once the game has crashed.
function TestConsole:hold(ticks, ...)
    local held = { ... }
    for _ = 1, ticks do
        if not self:step(held, {}) then
            return false
        end
    end
    return true
end

--- Plays the given number of ticks without any button; returns false once the game has crashed.
function TestConsole:wait(ticks)
    return self:hold(ticks)
end

--- Counts one check of the test, and prints its label when the condition is false.
function TestConsole.check(condition, label)
    TestConsole.checks = TestConsole.checks + 1
    if not condition then
        TestConsole.failures = TestConsole.failures + 1
        print("FAIL " .. label)
    end
end
