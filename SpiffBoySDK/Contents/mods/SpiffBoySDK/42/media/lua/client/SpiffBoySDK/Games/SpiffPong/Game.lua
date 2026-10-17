-- Spiff-Pong: the game class, entry point of the cartridge.
--
-- STRUCTURE OF A FULL CARTRIDGE
-- The console creates this class with GameClass:new(runtime, context) at each
-- power on, then calls tick(inputs, tick) once per fixed step and draw(screen)
-- once per frame until power off. The framework draws nothing of its own:
-- everything on the screen belongs to the game, title, menus, match, results
-- and best scores.
--
-- The code is split by role, each file small:
--   Game.lua     this file: the class, the screens table, tick and draw
--   Match.lua    the rules: paddles, ball, score (pure simulation)
--   Brain.lua    the console player
--   Link.lua     the two player protocol over the cable
--   Play.lua     running a match alone or in lockstep on the cable
--   Menus.lua    title, options, best scores and waiting screens
--   Results.lua  end of match and initials entry
--   View.lua     drawing helpers and the field
--   Records.lua, Options.lua  what the save keeps
--   Music.lua    tunes and sound effects
--
-- SCREENS AS A SMALL STATE MACHINE
-- self.mode names the current screen. Each screen has one tick method and one
-- draw method, listed in SCREENS below, and an open method (openTitle,
-- openOptions...) that sets the mode and prepares what the screen needs. A
-- screen changes the mode only by calling the open method of the next screen,
-- so every way into a screen goes through the same preparation.
--
-- FIXED TICK SIMULATION
-- tick() is one fixed step of the console, 1/60 of a second at normal game
-- speed, whatever the frame rate: between two frames the framework calls it as
-- many times as the elapsed time calls for (zero, one or several). All
-- movement is counted in ticks, never in milliseconds, which keeps the game
-- deterministic.
--
-- DRAW CALL BUDGET
-- The 301st draw call of a frame is an error that stops the game, as any
-- crash does. Every rect, sprite, layer of a layered sheet and every glyph of a
-- text (spaces excepted) costs one call (screen.calls counts them). This game
-- stays far below: a match frame is under 50 calls, the result about 55, and
-- the busiest screen, a full best scores table, under 90 in English. Prefer
-- one big rect to many small ones, short texts, and layered sheets drawn only
-- in the shades they use.

require "SpiffBoySDK/Core"
require "SpiffBoy/Core/GameBase"
require "SpiffBoy/Framework/Cartridges"
require "SpiffBoy/Framework/GameTexts"
require "SpiffBoySDK/Games/SpiffPong/Match"
require "SpiffBoySDK/Games/SpiffPong/Brain"
require "SpiffBoySDK/Games/SpiffPong/Link"
require "SpiffBoySDK/Games/SpiffPong/Music"
require "SpiffBoySDK/Games/SpiffPong/Records"
require "SpiffBoySDK/Games/SpiffPong/Options"
require "SpiffBoySDK/Games/SpiffPong/View"

-- The global name given as `game` in Definition.lua.
SpiffBoySDKPongGame = SpiffBoyGameBase:derive("SpiffBoySDKPongGame")

local Game = SpiffBoySDKPongGame
local Pong = SpiffBoySDK.SpiffPong
local Link = Pong.Link
local Music = Pong.Music
local Records = Pong.Records
local Options = Pong.Options

-- Every text of the game goes through this function, which picks the language
-- of the player from the Translate folder of the cartridge.
Game.text = SpiffBoy.GameTexts.of("SpiffPong")

Game.MODE_TITLE = "title"
Game.MODE_OPTIONS = "options"
Game.MODE_RECORDS = "records"
Game.MODE_WAITING = "waiting"
Game.MODE_PLAY = "play"
Game.MODE_RESULT = "result"
Game.MODE_INITIALS = "initials"

-- The screens of the game: the method that advances each one by a tick and
-- the method that draws it. The methods live in Menus, Play and Results.
local SCREENS = {
    [Game.MODE_TITLE] = { tick = "tickTitle", draw = "drawTitle" },
    [Game.MODE_OPTIONS] = { tick = "tickOptions", draw = "drawOptions" },
    [Game.MODE_RECORDS] = { tick = "tickRecords", draw = "drawRecords" },
    [Game.MODE_WAITING] = { tick = "tickWaiting", draw = "drawWaiting" },
    [Game.MODE_PLAY] = { tick = "tickPlay", draw = "drawPlay" },
    [Game.MODE_RESULT] = { tick = "tickResult", draw = "drawResult" },
    [Game.MODE_INITIALS] = { tick = "tickInitials", draw = "drawInitials" },
}

-- What a tick without any input state reads, so no screen has to test for nil.
local NO_INPUT = { held = {}, pressed = {} }

--- Switches the console on: loads the art, the save, the options and the port of the cable, then opens the title screen.
function Game:init()
    -- context.art(name) loads name.png from the art folder of the definition.
    local art = self.context.art
    self.logo = art("logo")
    self.digits = art("digits")
    self.records = Records.read(self.save)
    self.options = Options.read(self.save)
    self.port = Link.new(self.link)
    self.clock = 0
    self.twoPlayer = false
    self:applyMix()
    self:openTitle()
end

--- Gives the sequencer the level of the music the options ask for, the effects always at full level.
function Game:applyMix()
    if self.options.music then
        self.sequencer:setMix(1, 1)
    else
        self.sequencer:setMix(0, 1)
    end
end

--- Plays a sound effect on top of the music.
function Game:effect(name)
    self.sequencer:effect(name)
end

--- Starts the given looping music unless a tune is already playing, so a jingle ends before it.
function Game:keepMusic(name)
    if not self.sequencer:isPlaying() then
        self.sequencer:play(name)
    end
end

--- Advances the game by one fixed step: reads the cable, then runs the tick of the current screen.
function Game:tick(inputs, tick)
    self.clock = self.clock + 1
    self:pollLink()
    self[SCREENS[self.mode].tick](self, inputs[1] or NO_INPUT)
end

--- Draws the current screen.
function Game:draw(screen)
    self[SCREENS[self.mode].draw](self, screen)
end

--- Returns true while the current screen depends on the other console.
function Game:onCable()
    return self.mode == Game.MODE_WAITING or (self.mode == Game.MODE_PLAY and self.twoPlayer)
end

--- Reads what came up the cable and acts on it in the current screen: the cable lost or the other player gone send this console back to the title, a hello marks the other player as present, a start opens the match on the console that does not lead.
function Game:pollLink()
    local port = self.port
    -- The port is read on every screen, so pings are always answered and no
    -- old message waits in the queue when a two player screen opens.
    local events = port:poll(self.clock)
    if self:onCable() and not port:isConnected() then
        self:openTitle("CableLost")
        return
    end
    for _, event in ipairs(events) do
        if event.kind == Link.KIND_BYE and self:onCable() then
            self:openTitle("OtherLeft")
            return
        elseif event.kind == Link.KIND_HELLO and self.mode == Game.MODE_WAITING then
            self.peerSeen = true
        elseif event.kind == Link.KIND_START and self.mode == Game.MODE_WAITING and not port:leads() then
            self:startLinkedMatch(event.seed, event.delay, event.speed, event.points, 0)
        end
    end
end

require "SpiffBoySDK/Games/SpiffPong/Menus"
require "SpiffBoySDK/Games/SpiffPong/Play"
require "SpiffBoySDK/Games/SpiffPong/Results"
