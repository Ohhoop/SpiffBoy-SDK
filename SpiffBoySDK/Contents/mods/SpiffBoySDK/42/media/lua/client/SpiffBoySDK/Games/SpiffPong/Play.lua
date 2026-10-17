-- Playing a match of Spiff-Pong: alone against the console, or with another
-- player on the link cable in deterministic lockstep (see Link.lua for why).
--
-- DETERMINISTIC RANDOM
-- The match draws its serves from its own generator seeded by the seed of the
-- match. Alone, the seed comes from self.random, the generator the framework
-- seeds for this console. On the cable, the owner draws it and sends it in the
-- start message, so both consoles create the same generator. Nothing in the
-- match may read math.random, ZombRand or the time: a single number drawn
-- differently on one console and the two matches drift apart for good.

require "SpiffBoySDK/Core"

local Game = SpiffBoySDKPongGame
local Pong = SpiffBoySDK.SpiffPong
local Match = Pong.Match
local Brain = Pong.Brain
local Music = Pong.Music
local View = Pong.View
local text = Game.text

local SEED_MAX = 2000000000
-- At most this many match ticks run in one frame when the match fell behind
-- the frames because the input of the other console came late.
local CATCH_UP = 3
-- The two consoles compare a checksum of the match every this many ticks.
local CHECK_EVERY = 60
-- A stall longer than this many frames shows that the game waits for the cable.
local STALL_NOTICE = 30
local NEUTRAL = { up = false, down = false }
local LABEL_Y = 52
local LABEL_X = { 36, 144 }

--- Returns what the paddle holds this tick: up and down held, or pressed and released within the tick.
local function heldOf(input)
    local held, pressed = input.held, input.pressed
    return { up = held.up == true or pressed.up == true, down = held.down == true or pressed.down == true }
end

--- Starts a match against the console with the options of the cartridge, the player on the left.
function Game:startSoloMatch()
    local seed = self.random:int(1, SEED_MAX)
    self.twoPlayer = false
    self.mySide = 1
    self.match = Match.new(seed, self.options.speed, self.options.points)
    self.brain = Brain.new(seed + 1)
    self:openPlay()
end

--- Starts the match of the two players of the cable from the settings of the start message (seed, input delay and the options of the owner, each brought back within its bounds), the first tick held back by the given number of frames.
function Game:startLinkedMatch(seed, delay, speed, points, holdBack)
    speed = SpiffBoy.clamp(speed, 1, #Match.SPEEDS)
    points = SpiffBoy.clamp(points, 1, #Match.POINTS)
    self.twoPlayer = true
    -- The owner of the cable plays on the left, the other console on the right.
    -- Both agree on this without a message, since both know their seat.
    if self.port:leads() then
        self.mySide = 1
    else
        self.mySide = 2
    end
    self.match = Match.new(seed, speed, points)
    self.delay = delay
    -- frame counts the calls of tickLinked on this console (one per game tick),
    -- simTick the match ticks already simulated, sentTick the last tick whose
    -- input was sent.
    -- The first `delay` ticks need no message: both consoles read them as
    -- nothing pressed, so the first input sent is the one of tick `delay`.
    -- A frame count below zero holds the match back: nothing is sent and no
    -- tick runs until it reaches 1 (see "Starting together" in Link.lua).
    self.frame = -holdBack
    self.simTick = 0
    self.sentTick = delay - 1
    self.stallFrames = 0
    self:openPlay()
end

--- Opens the match screen with the start jingle.
function Game:openPlay()
    self.mode = Game.MODE_PLAY
    self.paused = false
    self.sequencer:stop()
    self.sequencer:play(Music.START)
end

--- Advances the match screen by one tick: the pause alone, otherwise the match alone or in step with the other console, then the sounds of what happened, then the result once a player won.
function Game:tickPlay(input)
    local pressed = input.pressed
    if self.twoPlayer then
        -- There is no pause on the cable: the other console would keep waiting.
        self:tickLinked(heldOf(input))
    elseif self.paused then
        if pressed.start then
            self.paused = false
            self:effect(Music.PAUSE)
        elseif pressed.b then
            self:effect(Music.BACK)
            self:openTitle()
        end
        return
    elseif pressed.start then
        self.paused = true
        self:effect(Music.PAUSE)
        return
    else
        self.match:tick(heldOf(input), self.brain:think(self.match, 2))
    end
    self:hearMatch()
    if self.match:isOver() then
        self:openResult()
    end
end

--- Returns the input of this console and of the other one for a match tick, or nil while one of them is unknown; the first ticks of the delay read as nothing pressed.
function Game:inputsOf(tick)
    if tick < self.delay then
        return NEUTRAL, NEUTRAL
    end
    local port = self.port
    local mine, theirs = port:localInput(tick), port:remoteInput(tick)
    if not mine or not theirs then
        return nil, nil
    end
    return mine, theirs
end

--- Advances the match of the cable by one frame: sends the input of this frame for the tick `delay` ahead, then runs every match tick whose two inputs are known, up to a few per frame, and sends a checksum now and then.
function Game:tickLinked(held)
    local port = self.port
    local match = self.match
    self.frame = self.frame + 1
    -- 1. Send. The input pressed now is for tick frame - 1 + delay. If the
    -- port refused a message (four per tick at most), the tick is sent on the
    -- next frame with the buttons held then; what is kept locally is always
    -- exactly what was sent, so both consoles simulate the same input.
    while self.sentTick < self.frame - 1 + self.delay do
        if not port:sendInput(self.sentTick + 1, held) then
            break
        end
        self.sentTick = self.sentTick + 1
    end
    -- 2. Simulate. Only ticks whose two inputs are known run, in order. The
    -- owner is always the left paddle, so both consoles call
    -- match:tick(left, right) with the same two inputs in the same order.
    local steps = 0
    while steps < CATCH_UP and self.simTick < self.frame and not match:isOver() do
        local mine, theirs = self:inputsOf(self.simTick)
        if not mine then
            break
        end
        if self.mySide == 1 then
            match:tick(mine, theirs)
        else
            match:tick(theirs, mine)
        end
        port:forget(self.simTick)
        -- 3. Check. Both consoles sum up the match after the same ticks and
        -- compare: a difference means a bug that broke determinism.
        if self.simTick % CHECK_EVERY == 0 then
            port:sendCheck(self.simTick, match:checksum())
        end
        self.simTick = self.simTick + 1
        steps = steps + 1
    end
    if steps == 0 and self.frame > 0 then
        self.stallFrames = self.stallFrames + 1
    else
        self.stallFrames = 0
    end
end

--- Turns the events of the match into sound effects.
function Game:hearMatch()
    for _, event in ipairs(self.match:takeEvents()) do
        if event.kind == "paddle" then
            self:effect(Music.PADDLE)
        elseif event.kind == "wall" then
            self:effect(Music.WALL)
        elseif event.kind == "point" then
            self:effect(Music.POINT)
        end
    end
end

--- Draws the match: the field, who plays which paddle before the first serve, the wait for the cable and the pause.
function Game:drawPlay(screen)
    local match = self.match
    View.field(screen, match, self.digits)
    if match.serves == 0 then
        View.centre(screen, text("You"), LABEL_X[self.mySide], LABEL_Y, View.INK)
        if not self.twoPlayer then
            View.centre(screen, text("Console"), LABEL_X[3 - self.mySide], LABEL_Y, View.DIM)
        end
    end
    if self.twoPlayer and self.stallFrames > STALL_NOTICE then
        View.centre(screen, text("Waiting"), View.CENTRE, 98, View.DIM)
    end
    if self.paused then
        View.box(screen, 30, 30, 120, 60)
        View.centre(screen, text("Paused"), View.CENTRE, 34, View.INK)
        View.centre(screen, text("ResumeHint"), View.CENTRE, 52, View.DIM)
        View.centre(screen, text("QuitHint"), View.CENTRE, 68, View.DIM)
    end
end
