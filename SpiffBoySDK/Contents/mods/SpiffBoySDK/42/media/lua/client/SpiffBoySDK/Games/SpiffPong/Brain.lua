-- The console player of Spiff-Pong: it presses up and down for the right paddle.
--
-- The brain does not move the paddle itself. It returns the same kind of input
-- a human gives, { up = ..., down = ... }, and the match moves the paddle with
-- the same rules for both sides. A brain that only "presses buttons" can never
-- cheat, and the match code stays the same for one or two players.
--
-- To be beatable it aims a little off the ball (a new error at each hit and
-- each serve) and only presses on three ticks out of four, which makes its
-- paddle slower than a human's. Its error comes from its own seeded generator,
-- so a replay of the same match with the same inputs gives the same game.

require "SpiffBoySDK/Core"
require "SpiffBoy/Core/Random"
require "SpiffBoySDK/Games/SpiffPong/Match"

local Match = SpiffBoySDK.SpiffPong.Match

local Brain = {}
Brain.__index = Brain
SpiffBoySDK.SpiffPong.Brain = Brain

local SUB = Match.SUB
-- The brain rests one tick in REST_EVERY.
local REST_EVERY = 4
-- How far off the ball the brain may aim, in pixels each way.
local AIM_ERROR = 7
-- The brain leaves its paddle alone while it is this close to its target, in sub pixels.
local DEAD_ZONE = 3 * SUB
local IDLE = { up = false, down = false }

--- Creates the brain of the console with its own generator seeded from the given number.
function Brain.new(seed)
    local o = setmetatable({}, Brain)
    o.random = SpiffBoyRandom.new(seed)
    o.aim = 0
    o.seenRally = -1
    o.seenServes = -1
    return o
end

--- Draws a new aiming error after every hit and every serve of the match.
function Brain:reaim(match)
    if match.rally ~= self.seenRally or match.serves ~= self.seenServes then
        self.seenRally = match.rally
        self.seenServes = match.serves
        self.aim = self.random:int(-AIM_ERROR, AIM_ERROR) * SUB
    end
end

--- Returns the buttons the brain holds this tick for the paddle of the given side: toward the ball when it comes, back to the middle otherwise.
function Brain:think(match, side)
    self:reaim(match)
    -- match.ticks only grows, so this % never sees a negative number.
    if match.ticks % REST_EVERY == 0 then
        return IDLE
    end
    local paddle = match.paddles[side]
    local centre = paddle.y + Match.PADDLE_H * SUB / 2
    local target = (Match.TOP + Match.BOTTOM) * SUB / 2
    local ball = match.ball
    local coming = (side == 2 and ball.vx > 0) or (side == 1 and ball.vx < 0)
    if match.phase == Match.PHASE_PLAY and coming then
        target = ball.y + Match.BALL * SUB / 2 + self.aim
    end
    if target < centre - DEAD_ZONE then
        return { up = true, down = false }
    end
    if target > centre + DEAD_ZONE then
        return { up = false, down = true }
    end
    return IDLE
end
