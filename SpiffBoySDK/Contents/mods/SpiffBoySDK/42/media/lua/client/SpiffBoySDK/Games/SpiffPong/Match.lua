-- The match of Spiff-Pong: the pure simulation of two paddles and a ball.
--
-- This file knows nothing about the screen, the sound, the buttons or the
-- cable. It takes what the two paddles do this tick and moves the world one
-- fixed step of 1/60 s forward. Keeping the rules apart like this is what makes
-- the two player mode possible: both consoles run this same code with the same
-- inputs and the same seed, so they compute the very same match (see Link.lua).
--
-- Determinism rules followed here:
--   * Every position and speed is a whole number of sub pixels (SUB per pixel),
--     never a fraction, so no rounding can differ from one machine to another.
--   * The only randomness comes from self.random, a SpiffBoyRandom seeded with
--     the seed of the match. Never math.random, ZombRand or a clock here.
--   * Divisions of values that can be negative go through divide(), which
--     rounds toward zero the same way for both signs.
--   * The match never reads anything outside itself: no global state.

require "SpiffBoySDK/Core"
require "SpiffBoy/Core/Random"

SpiffBoySDK.SpiffPong = SpiffBoySDK.SpiffPong or {}

local Match = {}
Match.__index = Match
SpiffBoySDK.SpiffPong.Match = Match

-- Sub pixels per screen pixel: the ball can move 1.5 pixels a tick as 24 sub pixels.
Match.SUB = 16
Match.WIDTH = 180
Match.HEIGHT = 120
-- The walls are the two top rows and the two bottom rows of the screen.
Match.TOP = 2
Match.BOTTOM = 118
Match.PADDLE_W = 3
Match.PADDLE_H = 16
-- The left edge of the left paddle and of the right paddle, in pixels.
Match.PADDLE_X = { 8, 169 }
Match.BALL = 3
-- Base horizontal speed of the ball for each option of speed, in sub pixels per tick.
Match.SPEEDS = { 16, 22, 28 }
-- Points a player needs to win, for each option of points.
Match.POINTS = { 5, 7, 11 }

local SUB = Match.SUB
local PADDLE_SPEED = 32
local SPEED_UP = 1
local MAX_EXTRA = 16
local SERVE_TICKS = 50
local FIRST_SERVE_TICKS = 100
local SERVE_MARGIN = 24
-- The offset from the centre of the paddle, in sub pixels, that bends the ball by one full speed.
local ANGLE_RANGE = 8 * SUB
local CHECK_MODULUS = 65536
-- Added to every value of the checksum so it never adds a negative number.
local CHECK_OFFSET = 1048576

Match.PHASE_SERVE = "serve"
Match.PHASE_PLAY = "play"
Match.PHASE_OVER = "over"

--- Returns a divided by b rounded toward zero, the same way for negative and positive values.
local function divide(a, b)
    if a < 0 then
        return -math.floor(-a / b)
    end
    return math.floor(a / b)
end

--- Returns the value brought back between the given bounds.
local function clamp(value, low, high)
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

--- Creates a match from its settings: seed, index of the speed option and index of the points option; the first serve heads to a side drawn from the seed.
function Match.new(seed, speedIndex, pointsIndex)
    local o = setmetatable({}, Match)
    -- The match owns its own generator. On the cable both consoles create it
    -- with the seed the owner of the cable sent, so both draw the same numbers.
    o.random = SpiffBoyRandom.new(seed)
    o.baseSpeed = Match.SPEEDS[speedIndex]
    o.target = Match.POINTS[pointsIndex]
    local middle = divide((Match.TOP + Match.BOTTOM - Match.PADDLE_H) * SUB, 2)
    o.paddles = { { y = middle }, { y = middle } }
    o.ball = { x = 0, y = 0, vx = 0, vy = 0 }
    o.score = { 0, 0 }
    o.rally = 0
    o.longestRally = 0
    o.serves = 0
    o.ticks = 0
    o.winner = nil
    o.events = {}
    o.towards = o.random:int(1, 2)
    o:waitServe(FIRST_SERVE_TICKS)
    return o
end

--- Records something that happened this tick, for the game to turn into sound.
function Match:emit(kind, side)
    self.events[#self.events + 1] = { kind = kind, side = side }
end

--- Returns the events of the ticks since the last call and forgets them.
function Match:takeEvents()
    local events = self.events
    self.events = {}
    return events
end

--- Returns true once a player reached the points to win.
function Match:isOver()
    return self.phase == Match.PHASE_OVER
end

--- Hides the ball and counts down the given ticks before the next serve.
function Match:waitServe(ticks)
    self.phase = Match.PHASE_SERVE
    self.timer = ticks
end

--- Advances the match by one fixed step with what each paddle holds: a table with up and down for the left paddle and for the right one.
function Match:tick(left, right)
    if self.phase == Match.PHASE_OVER then
        return
    end
    self.ticks = self.ticks + 1
    -- Paddles move in every phase, so players can place them before a serve.
    self:movePaddle(1, left)
    self:movePaddle(2, right)
    if self.phase == Match.PHASE_SERVE then
        self.timer = self.timer - 1
        if self.timer <= 0 then
            self:serve()
        end
        return
    end
    self:moveBall()
end

--- Moves a paddle up or down by its speed, kept between the walls.
function Match:movePaddle(side, held)
    local paddle = self.paddles[side]
    local step = 0
    if held.up then
        step = step - PADDLE_SPEED
    end
    if held.down then
        step = step + PADDLE_SPEED
    end
    paddle.y = clamp(paddle.y + step, Match.TOP * SUB, (Match.BOTTOM - Match.PADDLE_H) * SUB)
end

--- Puts the ball in the middle of the field and sends it to the side the serve heads to, at a height and an angle drawn from the generator of the match.
function Match:serve()
    local ball = self.ball
    local speed = self.baseSpeed
    ball.x = divide((Match.WIDTH - Match.BALL) * SUB, 2)
    ball.y = self.random:int((Match.TOP + SERVE_MARGIN) * SUB, (Match.BOTTOM - SERVE_MARGIN - Match.BALL) * SUB)
    ball.vy = self.random:int(-divide(speed, 2), divide(speed, 2))
    if self.towards == 1 then
        ball.vx = -speed
    else
        ball.vx = speed
    end
    self.extra = 0
    self.rally = 0
    self.serves = self.serves + 1
    self.phase = Match.PHASE_PLAY
    self:emit("serve", self.towards)
end

--- Returns true when the ball overlaps the paddle of the given side vertically.
function Match:touches(side)
    local paddle = self.paddles[side]
    local ball = self.ball
    return ball.y + Match.BALL * SUB > paddle.y and ball.y < paddle.y + Match.PADDLE_H * SUB
end

--- Moves the ball one step: it bounces on the walls, on a paddle whose face it crossed this tick, or leaves the field and gives a point.
function Match:moveBall()
    local ball = self.ball
    local oldX = ball.x
    ball.x = ball.x + ball.vx
    ball.y = ball.y + ball.vy
    local top = Match.TOP * SUB
    local bottom = (Match.BOTTOM - Match.BALL) * SUB
    -- A wall reflects the part of the move that went past it, so no speed is lost.
    if ball.y < top then
        ball.y = top + (top - ball.y)
        ball.vy = -ball.vy
        self:emit("wall")
    elseif ball.y > bottom then
        ball.y = bottom - (ball.y - bottom)
        ball.vy = -ball.vy
        self:emit("wall")
    end
    -- The paddle test is swept: it asks whether the ball crossed the face of
    -- the paddle between its old and new position, so a fast ball moving
    -- several pixels a tick can never jump through a thin paddle.
    if ball.vx < 0 then
        local face = (Match.PADDLE_X[1] + Match.PADDLE_W) * SUB
        if oldX >= face and ball.x < face and self:touches(1) then
            self:bounce(1, face)
        end
    else
        local face = (Match.PADDLE_X[2] - Match.BALL) * SUB
        if oldX <= face and ball.x > face and self:touches(2) then
            self:bounce(2, face)
        end
    end
    if ball.x + Match.BALL * SUB < 0 then
        self:point(2)
    elseif ball.x > Match.WIDTH * SUB then
        self:point(1)
    end
end

--- Sends the ball back from the paddle of the given side whose face lies at the given x: a little faster each hit, bent up or down by where it hit the paddle.
function Match:bounce(side, face)
    local ball = self.ball
    local paddle = self.paddles[side]
    ball.x = face + face - ball.x
    self.extra = math.min(self.extra + SPEED_UP, MAX_EXTRA)
    local speed = self.baseSpeed + self.extra
    -- Hitting with the edge of the paddle sends the ball steeper.
    local offset = (ball.y + divide(Match.BALL * SUB, 2)) - (paddle.y + divide(Match.PADDLE_H * SUB, 2))
    ball.vy = clamp(divide(offset * speed, ANGLE_RANGE), -speed, speed)
    if side == 1 then
        ball.vx = speed
    else
        ball.vx = -speed
    end
    self.rally = self.rally + 1
    self.longestRally = math.max(self.longestRally, self.rally)
    self:emit("paddle", side)
end

--- Gives a point to the given side; the match ends at the points to win, otherwise the next serve heads to the side that lost the point.
function Match:point(scorer)
    self.score[scorer] = self.score[scorer] + 1
    self:emit("point", scorer)
    if self.score[scorer] >= self.target then
        self.phase = Match.PHASE_OVER
        self.winner = scorer
        self:emit("over", scorer)
        return
    end
    self.towards = 3 - scorer
    self:waitServe(SERVE_TICKS)
end

--- Returns a number from 0 to 65535 summing up the whole state of the match, so two consoles can check they still agree.
function Match:checksum()
    local ball = self.ball
    local values = {
        ball.x, ball.y, ball.vx, ball.vy, self.paddles[1].y, self.paddles[2].y,
        self.score[1], self.score[2], self.ticks, self.timer, self.random.state % CHECK_MODULUS,
    }
    local sum = 0
    for i = 1, #values do
        -- Every value is made positive before the modulo, because % in Kahlua
        -- truncates toward zero and would give a negative rest for a negative value.
        sum = (sum * 31 + values[i] + CHECK_OFFSET) % CHECK_MODULUS
    end
    return sum
end
