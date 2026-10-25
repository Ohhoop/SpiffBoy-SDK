-- Plays Spiff-Pong on two consoles joined by a simulated link cable, loaded
-- after tests/robots/preamble.lua. The cable delivers each message a fixed
-- number of ticks late, in order, and refuses a fifth message in one tick as
-- the real port does. Returns one result table per scenario.

local scenarios = ...

require "SpiffBoySDK/Games/SpiffPong/Definition"
require "SpiffBoySDK/Games/SpiffPong/Game"

local Pong = SpiffBoySDK.SpiffPong
local Game = SpiffBoySDKPongGame
local SUB = Pong.Match.SUB

local missingTexts = 0
local rawLog = SpiffBoy.log
SpiffBoy.log = function(message)
    if string.find(tostring(message), "has no text", 1, true) then
        missingTexts = missingTexts + 1
    end
    rawLog(message)
end

local owner = {
    drawRect = function() end, drawSubTexture = function() end, drawTextureScaled = function() end,
    drawTextureAllPoint = function() end, setStencilRect = function() end, clearStencilRect = function() end,
}

--- Returns a cable with the given delay in ticks and a port per seat.
local function newCable(delay)
    local cable = { queues = { {}, {} }, delay = delay, clock = 0, connected = true, refused = 0 }
    local ports = {}
    for seat = 1, 2 do
        local port = { sent = 0 }
        function port:isConnected() return cable.connected end
        function port:seat() if cable.connected then return seat end return nil end
        function port:send(message)
            if not cable.connected then return false end
            assert(type(message) == "string" and #message >= 1 and #message <= 16, "bad message length")
            if self.sent >= 4 then
                cable.refused = cable.refused + 1
                return false
            end
            self.sent = self.sent + 1
            local queue = cable.queues[3 - seat]
            queue[#queue + 1] = { at = cable.clock + cable.delay, message = message }
            return true
        end
        function port:receive()
            local queue = cable.queues[seat]
            if queue[1] and queue[1].at <= cable.clock then
                return table.remove(queue, 1).message
            end
            return nil
        end
        ports[seat] = port
    end
    cable.ports = ports
    return cable
end

--- Creates a console running Spiff-Pong on the given port with the given seed.
local function newConsole(port, seed)
    local definition = SpiffBoy.Cartridges.byId("SpiffPong")
    local screen = SpiffBoyScreen.new(owner, 180, 120)
    screen:setPalette(SpiffBoy.Cartridges.SHADES)
    screen:setWholePixels(true)
    screen:setPlacement(0, 0, 1)
    local runtime = SpiffBoyRuntime.new(screen)
    local chip = SpiffBoyChip.new()
    chip:boot()
    local sequencer = SpiffBoySequencer.new(chip, SpiffBoy.Tunes.set("SpiffPong"))
    local console = { screen = screen, runtime = runtime, input = SpiffBoyInputState.new(), saves = 0, most = 0, ticks = 0 }
    local context = {
        seed = seed, definition = definition, art = SpiffBoy.Textures.folder(definition.mod, definition.art, true),
        chip = chip, sequencer = sequencer, link = port, save = {},
        persist = function() console.saves = console.saves + 1 end,
    }
    assert(runtime:start(Game, context), "the game did not start")
    runtime:setDevices({ sequencer, chip })
    console.game = runtime.game
    return console
end

--- Runs one tick and one frame of a console with the given buttons held; returns false when the game crashed.
local function step(console, buttons)
    local input = console.input
    input:clearHeld()
    for name, down in pairs(buttons) do
        input.held[name] = down
    end
    input:latch()
    console.ticks = console.ticks + 1
    local runtime = console.runtime
    runtime.acting = input:anyPressed()
    local ticked = runtime:guard("tick", runtime.game.tick, { input }, console.ticks)
    runtime.acting = false
    if not ticked then
        return false
    end
    for _, device in ipairs(runtime.devices) do
        device:step()
    end
    runtime:draw()
    if runtime.crash then
        return false
    end
    if console.screen.calls > console.most then
        console.most = console.screen.calls
    end
    return true
end

--- Returns the buttons a test player presses: through the title to two players (or one), then a paddle that follows the ball with an error changing every second, then A on the result.
local function drive(game, frame, wantTwo, side)
    local mode = game.mode
    local odd = frame % 2 == 0
    if mode == Game.MODE_TITLE then
        local entry = wantTwo and 2 or 1
        if game.menuIndex ~= entry then
            return { down = odd }
        end
        return { a = odd }
    end
    if mode == Game.MODE_PLAY then
        local match = game.match
        local paddle = match.paddles[side]
        local aimError = ((math.floor(frame / 90) * 7919 + side * 31) % 21 - 10) * SUB
        local target = match.ball.y + aimError
        local centre = paddle.y + Pong.Match.PADDLE_H * SUB / 2
        return { up = target < centre - 2 * SUB, down = target > centre + 2 * SUB }
    end
    if mode == Game.MODE_INITIALS or mode == Game.MODE_RESULT or mode == Game.MODE_RECORDS then
        return { a = odd }
    end
    return {}
end

--- Gives every new match a history table.
local rawNew = Pong.Match.new
Pong.Match.new = function(...)
    local match = rawNew(...)
    match.history = {}
    return match
end

--- Records the state of a match after every tick, keyed by its tick number, on its history table.
local rawTick = Pong.Match.tick
Pong.Match.tick = function(self, left, right)
    rawTick(self, left, right)
    if self.history then
        local ball = self.ball
        self.history[self.ticks] = table.concat({ ball.x, ball.y, ball.vx, ball.vy, self.paddles[1].y, self.paddles[2].y, self.score[1], self.score[2], self.phase }, ",")
    end
end

--- Plays two consoles on one cable through a whole match and returns what happened.
local function linked(scenario)
    local cable = newCable(scenario.delay)
    local a = newConsole(cable.ports[1], 1111)
    local b = newConsole(cable.ports[2], 2222)
    local result = { name = scenario.name, crash = "", compared = 0, mismatches = 0, stalls = 0, frames = 0 }
    local hookedA, hookedB = nil, nil
    local done = 0
    for frame = 1, scenario.frames do
        cable.clock = cable.clock + 1
        cable.ports[1].sent, cable.ports[2].sent = 0, 0
        if scenario.cutAt and frame == scenario.cutAt then
            cable.connected = false
        end
        local buttonsA = drive(a.game, frame, true, 1)
        local buttonsB = {}
        if frame > (scenario.lateB or 0) then
            buttonsB = drive(b.game, frame, true, 2)
        end
        if not step(a, buttonsA) then result.crash = "A: " .. a.runtime.crash.message break end
        if not step(b, buttonsB) then result.crash = "B: " .. b.runtime.crash.message break end
        if a.game.match then hookedA = a.game.match end
        if b.game.match then hookedB = b.game.match end
        if a.game.mode == Game.MODE_PLAY and a.game.twoPlayer and a.game.stallFrames > 30 then result.stalls = result.stalls + 1 end
        if b.game.mode == Game.MODE_PLAY and b.game.twoPlayer and b.game.stallFrames > 30 then result.stalls = result.stalls + 1 end
        result.frames = frame
        if a.game.mode == Game.MODE_RESULT and b.game.mode == Game.MODE_RESULT then
            done = done + 1
            if done > 5 then break end
        end
        if scenario.cutAt and frame > scenario.cutAt + 5 then break end
    end
    if hookedA and hookedB then
        local last = math.min(hookedA.ticks, hookedB.ticks)
        for t = 1, last do
            result.compared = result.compared + 1
            if hookedA.history[t] ~= hookedB.history[t] then
                result.mismatches = result.mismatches + 1
            end
        end
        result.scoreA = hookedA.score[1] .. "-" .. hookedA.score[2]
        result.scoreB = hookedB.score[1] .. "-" .. hookedB.score[2]
        result.rally = hookedA.longestRally
    end
    result.modeA, result.modeB = a.game.mode, b.game.mode
    result.noticeA, result.noticeB = tostring(a.game.notice), tostring(b.game.notice)
    result.wonA, result.wonB = tostring(a.game.won), tostring(b.game.won)
    result.checksums = a.game.port.mismatches + b.game.port.mismatches
    result.refused = cable.refused
    result.most = math.max(a.most, b.most)
    result.delay = a.game.delay or 0
    return result
end

--- Plays one console alone through a whole match against the console, the initials and the best scores.
local function solo(scenario)
    local alone = { isConnected = function() return false end, seat = function() return nil end, send = function() return false end, receive = function() return nil end }
    local c = newConsole(alone, 31337)
    local result = { name = scenario.name, crash = "", compared = 0, mismatches = 0, stalls = 0, frames = 0, checksums = 0, refused = 0 }
    local sawRecords = false
    for frame = 1, scenario.frames do
        if not step(c, drive(c.game, frame, false, 1)) then result.crash = c.runtime.crash.message break end
        result.frames = frame
        if c.game.mode == Game.MODE_RECORDS then sawRecords = true end
        if sawRecords and c.game.mode == Game.MODE_TITLE then break end
    end
    result.modeA = c.game.mode
    result.saves = c.saves
    result.records = #c.game.records.rallies
    result.wins = c.game.records.wins
    result.losses = c.game.records.losses
    result.sawRecords = sawRecords
    result.most = c.most
    return result
end

local results = {}
for i, scenario in ipairs(scenarios) do
    if scenario.solo then
        results[i] = solo(scenario)
    else
        results[i] = linked(scenario)
    end
end
results.missingTexts = missingTexts
return results
