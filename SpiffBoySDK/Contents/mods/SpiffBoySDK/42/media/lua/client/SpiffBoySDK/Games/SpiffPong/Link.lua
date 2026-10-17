-- The two player protocol of Spiff-Pong over the link cable.
--
-- WHY LOCKSTEP
-- Each player keeps their own console, and the cable only carries short text
-- messages (1 to 16 bytes, at most 4 per tick, arriving 100 to 200 ms late in
-- multiplayer). Sending the position of the ball every tick would be too much
-- and would arrive late anyway. Instead, both consoles run the whole match
-- themselves (Match.lua) and only send each other their buttons. If both start
-- from the same seed and apply the same buttons on the same tick, the match is
-- a pure function of those inputs, so both screens show exactly the same ball.
--
-- HOW INPUTS ARE DELAYED
-- Here a frame is one call of tick() of the game (self.frame in Play.lua) and
-- a match tick is one step of Match.lua; the two drift apart while the match
-- waits for the cable. The input a player presses on frame F is applied at
-- match tick F - 1 + delay.
-- It is sent at once, so it has `delay` ticks to cross the cable before the
-- other console needs it. Both consoles treat the first `delay` ticks as
-- "nothing pressed" without sending anything, since both know the delay. A
-- match tick runs only when both inputs for it are known; if the other input is
-- late the match waits (a stall) and catches up a few ticks per frame later.
-- The owner of the cable measures the round trip with pings first and picks a
-- delay just long enough to hide the trip of one message.
--
-- STARTING TOGETHER
-- The start message itself takes half a round trip to arrive, so the other
-- console begins later than the owner. Were the owner to begin at once, it
-- would always run that much ahead, waiting for inputs that cannot be there
-- yet, and its player would feel twice the delay. So the owner holds its first
-- match tick back by half the round trip: both consoles then begin at about
-- the same moment, and an input sent `delay` ticks ahead arrives in time.
--
-- MESSAGES (first byte is the kind)
--   H              hello: this console waits on the two player screen
--   B              bye: this console left the two player game
--   P t t          ping stamped with a tick (2 bytes), answered by Q t t
--   S m s s s s d v p   start of match m with a 4 byte seed, the delay, the speed and points options
--   I m t t b      input of match m for tick t (2 bytes): b holds up (1) and down (2)
--   C m t t c c    checksum c of match m after tick t, to detect a desync
-- The match number m lets a console ignore messages of an older match.

require "SpiffBoySDK/Core"

SpiffBoySDK.SpiffPong = SpiffBoySDK.SpiffPong or {}

local Link = {}
Link.__index = Link
SpiffBoySDK.SpiffPong.Link = Link

Link.KIND_HELLO = "H"
Link.KIND_BYE = "B"
Link.KIND_PING = "P"
Link.KIND_PONG = "Q"
Link.KIND_START = "S"
Link.KIND_INPUT = "I"
Link.KIND_CHECK = "C"

Link.MIN_DELAY = 4
Link.MAX_DELAY = 20
Link.EXTRA_DELAY = 3
Link.PINGS = 4
-- Ticks travel as two bytes, so they wrap at 65536; inputs are keyed by this
-- wrapped value and forgotten once used, so an old key is never mistaken for a new one.
Link.TICK_MODULUS = 65536

local UP = 1
local DOWN = 2

--- Creates the protocol of the game over the link port of the console.
function Link.new(port)
    local o = setmetatable({}, Link)
    o.port = port
    o.matchId = 0
    o:reset()
    o:forgetMeasure()
    return o
end

--- Returns true while the cable joins two consoles switched on that run this cartridge.
function Link:isConnected()
    return self.port:isConnected()
end

--- Returns true when this console holds the cable (seat 1): it leads, choosing the seed and the delay.
function Link:leads()
    return self.port:seat() == 1
end

--- Returns the seat of this console on the cable, 1 or 2, or nil while the cable joins nothing.
function Link:seat()
    return self.port:seat()
end

--- Returns the two bytes of a tick number, high byte first.
local function tickBytes(tick)
    local value = tick % Link.TICK_MODULUS
    return string.char(math.floor(value / 256), value % 256)
end

--- Returns the tick number held by two bytes of a message from the given position.
local function tickAt(message, position)
    return string.byte(message, position) * 256 + string.byte(message, position + 1)
end

--- Sends a message down the cable; returns false when the port refused it this tick.
function Link:send(message)
    return self.port:send(message)
end

--- Forgets the inputs and checksums of the match and the ping in flight.
function Link:reset()
    self.local_ = {}
    self.remote = {}
    self.sums = {}
    self.peerSums = {}
    self.mismatches = 0
    self.pingSent = nil
end

--- Forgets the measure of the cable, so a new session measures it again.
function Link:forgetMeasure()
    self.pings = 0
    self.roundTrip = nil
    self.pingSent = nil
end

--- Tells the other console that this one waits on the two player screen.
function Link:hello()
    self:send(Link.KIND_HELLO)
end

--- Tells the other console that this one left the two player game.
function Link:bye()
    self:send(Link.KIND_BYE)
end

--- Returns true while the cable still needs pings to be measured and none is in flight.
function Link:needsPing()
    return self.pings < Link.PINGS and self.pingSent == nil
end

--- Returns true once every ping came back.
function Link:measured()
    return self.pings >= Link.PINGS and self.pingSent == nil
end

--- Sends a ping stamped with the given tick to measure the round trip of the cable.
function Link:ping(tick)
    if self:send(Link.KIND_PING .. tickBytes(tick)) then
        self.pingSent = tick
        self.pings = self.pings + 1
    end
end

--- Returns the time a message takes to reach the other console, in ticks: half the longest round trip measured.
function Link:halfTrip()
    return math.ceil(self.roundTrip / 2)
end

--- Returns the input delay of the match: the time a message takes to cross the cable plus a margin, within the bounds.
function Link:delay()
    return SpiffBoy.clamp(self:halfTrip() + Link.EXTRA_DELAY, Link.MIN_DELAY, Link.MAX_DELAY)
end

--- Opens the next match on this console and tells the other one its number, seed, delay and options; returns false when the port refused the message this tick.
function Link:sendStart(seed, delay, speed, points)
    local matchId = (self.matchId + 1) % 256
    local bytes = {}
    local value = seed
    for i = 4, 1, -1 do
        bytes[i] = value % 256
        value = math.floor(value / 256)
    end
    local message = Link.KIND_START .. string.char(matchId, bytes[1], bytes[2], bytes[3], bytes[4], delay, speed, points)
    if not self:send(message) then
        return false
    end
    self.matchId = matchId
    self:reset()
    return true
end

--- Sends the buttons of this console for the given match tick and keeps them for the simulation; returns false, keeping nothing, when the port refused the message.
function Link:sendInput(tick, held)
    local value = 0
    if held.up then
        value = value + UP
    end
    if held.down then
        value = value + DOWN
    end
    if not self:send(Link.KIND_INPUT .. string.char(self.matchId) .. tickBytes(tick) .. string.char(value)) then
        return false
    end
    self.local_[tick % Link.TICK_MODULUS] = value
    return true
end

--- Returns the buttons packed in a byte of input.
local function unpackInput(value)
    return { up = value % 2 == 1, down = math.floor(value / 2) % 2 == 1 }
end

--- Returns the buttons this console sent for the given match tick, or nil.
function Link:localInput(tick)
    local value = self.local_[tick % Link.TICK_MODULUS]
    if value == nil then
        return nil
    end
    return unpackInput(value)
end

--- Returns the buttons the other console sent for the given match tick, or nil while they have not arrived.
function Link:remoteInput(tick)
    local value = self.remote[tick % Link.TICK_MODULUS]
    if value == nil then
        return nil
    end
    return unpackInput(value)
end

--- Forgets both inputs of a match tick once the simulation used them.
function Link:forget(tick)
    local key = tick % Link.TICK_MODULUS
    self.local_[key] = nil
    self.remote[key] = nil
end

--- Compares the checksums of both consoles for a tick once both are known, counting and logging a mismatch.
function Link:compare(key)
    local mine, theirs = self.sums[key], self.peerSums[key]
    if mine == nil or theirs == nil then
        return
    end
    self.sums[key] = nil
    self.peerSums[key] = nil
    if mine ~= theirs then
        self.mismatches = self.mismatches + 1
        SpiffBoy.trace("Spiff-Pong: the two consoles disagree after tick " .. tostring(key))
    end
end

--- Keeps the checksum of the match after the given tick, sends it to the other console and compares it with theirs.
function Link:sendCheck(tick, sum)
    local key = tick % Link.TICK_MODULUS
    self.sums[key] = sum
    self:send(Link.KIND_CHECK .. string.char(self.matchId) .. tickBytes(tick) .. string.char(math.floor(sum / 256), sum % 256))
    self:compare(key)
end

--- Reads one start message into an event with its seed, delay and options, and opens that match on this console.
function Link:readStart(message)
    local seed = 0
    for i = 3, 6 do
        seed = seed * 256 + string.byte(message, i)
    end
    self.matchId = string.byte(message, 2)
    self:reset()
    return {
        kind = Link.KIND_START, seed = seed,
        delay = SpiffBoy.clamp(string.byte(message, 7), Link.MIN_DELAY, Link.MAX_DELAY),
        speed = string.byte(message, 8), points = string.byte(message, 9),
    }
end

--- Reads every message that came up the cable and returns the ones the game handles as events in order (hello, bye, start); pings are answered, pongs measure the round trip, inputs and checksums of the current match are kept.
function Link:poll(clock)
    local events = {}
    while true do
        local message = self.port:receive()
        if message == nil then
            break
        end
        local kind = string.sub(message, 1, 1)
        local length = string.len(message)
        if kind == Link.KIND_INPUT and length == 5 then
            if string.byte(message, 2) == self.matchId then
                self.remote[tickAt(message, 3)] = string.byte(message, 5)
            end
        elseif kind == Link.KIND_CHECK and length == 6 then
            if string.byte(message, 2) == self.matchId then
                local key = tickAt(message, 3)
                self.peerSums[key] = tickAt(message, 5)
                self:compare(key)
            end
        elseif kind == Link.KIND_PING and length == 3 then
            self:send(Link.KIND_PONG .. string.sub(message, 2, 3))
        elseif kind == Link.KIND_PONG and length == 3 then
            if self.pingSent and tickAt(message, 2) == self.pingSent % Link.TICK_MODULUS then
                self.roundTrip = math.max(self.roundTrip or 0, clock - self.pingSent)
                self.pingSent = nil
            end
        elseif kind == Link.KIND_START and length == 9 then
            -- The start is read here, in order, so the inputs of the new match
            -- that follow it in the same batch are already kept for it.
            events[#events + 1] = self:readStart(message)
        elseif kind == Link.KIND_HELLO or kind == Link.KIND_BYE then
            events[#events + 1] = { kind = kind }
        end
    end
    return events
end
