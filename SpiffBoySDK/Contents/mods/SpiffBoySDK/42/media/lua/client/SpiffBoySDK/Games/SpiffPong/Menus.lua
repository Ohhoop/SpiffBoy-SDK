-- The menu screens of Spiff-Pong: title, options, best scores and the screen
-- that waits for the other player on the cable. Each screen is an open method,
-- a tick method and a draw method of the game class (see SCREENS in Game.lua).

require "SpiffBoySDK/Core"

local Game = SpiffBoySDKPongGame
local Pong = SpiffBoySDK.SpiffPong
local Music = Pong.Music
local Options = Pong.Options
local Records = Pong.Records
local View = Pong.View
local text = Game.text

local TITLE_ENTRIES = { "OnePlayer", "TwoPlayers", "BestScores", "Options" }
local LOGO_W = 119
local LOGO_H = 15
local LOGO_Y = 8
-- The logo is a layered sheet: a row per shade. Drawing only the two shades it
-- uses costs two calls instead of four.
local LOGO_SHADES = { View.INK, View.SOFT }
local MENU_X = 52
local MENU_Y = 48
local MENU_STEP = 16
local NOTICE_TICKS = 240
local DEMO_LEFT = 46
local DEMO_RIGHT = 131
local DEMO_TITLE_Y = 28
local DEMO_WAITING_Y = 78
local OPTIONS_Y = 32
local OPTIONS_STEP = 20
local ROWS_Y = 22
local ROWS_STEP = 14
local FLASH_TICKS = 8
local HELLO_EVERY = 30
local PING_EVERY = 10
local SEED_MAX = 2000000000

--- Returns the menu step asked by up or down this tick: -1, 1 or 0.
local function verticalStep(pressed)
    if pressed.up then
        return -1
    end
    if pressed.down then
        return 1
    end
    return 0
end
Game.verticalStep = verticalStep

--- Returns the given index moved by a step and wrapped within 1 to count, without % on a negative number.
local function wrap(index, step, count)
    return (index - 1 + step + count) % count + 1
end
Game.wrap = wrap

--- Opens the title screen, leaving any match and two player session; an optional notice key shows a message for a few seconds.
function Game:openTitle(notice)
    self.mode = Game.MODE_TITLE
    self.menuIndex = self.menuIndex or 1
    self.twoPlayer = false
    self.match = nil
    self.port:reset()
    self.notice = notice
    self.noticeTimer = NOTICE_TICKS
end

--- Applies the input to the title menu: up and down move the cursor, A or Start opens the chosen entry; two players needs the cable joined to a console running this cartridge.
function Game:tickTitle(input)
    self:keepMusic(Music.TITLE)
    if self.notice then
        self.noticeTimer = self.noticeTimer - 1
        if self.noticeTimer <= 0 then
            self.notice = nil
        end
    end
    local pressed = input.pressed
    local step = verticalStep(pressed)
    if step ~= 0 then
        self.menuIndex = wrap(self.menuIndex, step, #TITLE_ENTRIES)
        self:effect(Music.MOVE)
    end
    if not (pressed.a or pressed.start) then
        return
    end
    local entry = TITLE_ENTRIES[self.menuIndex]
    if entry == "TwoPlayers" and not self.port:isConnected() then
        self:effect(Music.REFUSE)
        return
    end
    self:effect(Music.CONFIRM)
    if entry == "OnePlayer" then
        self:startSoloMatch()
    elseif entry == "TwoPlayers" then
        self:openWaiting()
    elseif entry == "BestScores" then
        self:openRecords(nil)
    else
        self:openOptions()
    end
end

--- Draws a tiny endless rally whose ball flies at the given height or a little lower, timed by the clock of the game: three calls.
function Game:drawDemo(screen, top)
    local span = DEMO_RIGHT - DEMO_LEFT - 3
    local position = self.clock % (span * 2)
    if position > span then
        position = span * 2 - position
    end
    local bounce = self.clock % 20
    if bounce > 10 then
        bounce = 20 - bounce
    end
    local ballY = top + bounce
    View.rect(screen, DEMO_LEFT, ballY - 4, 2, 10, View.DIM)
    View.rect(screen, DEMO_RIGHT, ballY - 4, 2, 10, View.DIM)
    View.rect(screen, DEMO_LEFT + 2 + position, ballY, 2, 2, View.INK)
end

--- Draws the title screen: the logo, the demo rally or a notice, and the menu with its cursor.
function Game:drawTitle(screen)
    View.clear(screen, View.PAPER)
    screen:layers(self.logo, 0, LOGO_W, LOGO_H, math.floor((View.WIDTH - LOGO_W) / 2), LOGO_Y, LOGO_SHADES)
    if self.notice then
        View.centre(screen, text(self.notice), View.CENTRE, LOGO_Y + LOGO_H + 3, View.INK)
    else
        self:drawDemo(screen, DEMO_TITLE_Y)
    end
    local cable = self.port:isConnected()
    for i, entry in ipairs(TITLE_ENTRIES) do
        local shade = View.INK
        if entry == "TwoPlayers" and not cable then
            shade = View.SOFT
        end
        View.text(screen, text(entry), MENU_X, MENU_Y + (i - 1) * MENU_STEP, shade)
    end
    View.cursor(screen, MENU_X, MENU_Y + (self.menuIndex - 1) * MENU_STEP)
end

--- Opens the options screen on its first entry.
function Game:openOptions()
    self.mode = Game.MODE_OPTIONS
    self.optionIndex = 1
    self.optionsChanged = false
end

--- Applies the input to the options: up and down choose an entry, left and right turn it, A, B or Start go back to the title and write the options when they changed.
function Game:tickOptions(input)
    self:keepMusic(Music.TITLE)
    local pressed = input.pressed
    local step = verticalStep(pressed)
    if step ~= 0 then
        self.optionIndex = wrap(self.optionIndex, step, #Options.ENTRIES)
        self:effect(Music.MOVE)
    end
    local turn = 0
    if pressed.left then
        turn = -1
    elseif pressed.right then
        turn = 1
    end
    if turn ~= 0 then
        Options.turn(self.options, Options.ENTRIES[self.optionIndex], turn)
        self.optionsChanged = true
        self:applyMix()
        self:effect(Music.MOVE)
    end
    if pressed.a or pressed.b or pressed.start then
        if self.optionsChanged then
            Options.write(self.save, self.options)
            self:persist()
        end
        self:effect(Music.BACK)
        self:openTitle()
    end
end

--- Returns the text of the current value of an option entry.
function Game:optionValue(entry)
    local value = self.options[entry.key]
    if entry.key == "music" then
        if value then
            return text("On")
        end
        return text("Off")
    end
    if entry.texts then
        return text(entry.texts[value])
    end
    return tostring(entry.values[value])
end

--- Draws the options: each entry with its value between arrows, the cursor and the way back.
function Game:drawOptions(screen)
    View.clear(screen, View.PAPER)
    View.centre(screen, text("Options"), View.CENTRE, 6, View.INK)
    for i, entry in ipairs(Options.ENTRIES) do
        local y = OPTIONS_Y + (i - 1) * OPTIONS_STEP
        View.text(screen, text(entry.text), 20, y, View.INK)
        View.right(screen, text("Choice", self:optionValue(entry)), 168, y, View.DIM)
    end
    View.cursor(screen, 20, OPTIONS_Y + (self.optionIndex - 1) * OPTIONS_STEP)
    View.centre(screen, text("BackHint"), View.CENTRE, 98, View.SOFT)
end

--- Opens the best scores, the given rank flashing when a new entry was just written there.
function Game:openRecords(rank)
    self.mode = Game.MODE_RECORDS
    self.flashRank = rank
end

--- Goes back to the title on A, B or Start.
function Game:tickRecords(input)
    self:keepMusic(Music.TITLE)
    local pressed = input.pressed
    if pressed.a or pressed.b or pressed.start then
        self:effect(Music.BACK)
        self:openTitle()
    end
end

--- Draws the five longest rallies with their initials, the new one flashing, and the matches won and lost against the console.
function Game:drawRecords(screen)
    View.clear(screen, View.PAPER)
    View.centre(screen, text("BestRallies"), View.CENTRE, 2, View.INK)
    local rallies = self.records.rallies
    local hidden = math.floor(self.clock / FLASH_TICKS) % 2 == 0
    for i = 1, Records.SIZE do
        local y = ROWS_Y + (i - 1) * ROWS_STEP
        local entry = rallies[i]
        if not (i == self.flashRank and hidden) then
            View.right(screen, text("Rank", i), 52, y, View.DIM)
            if entry then
                View.text(screen, entry.initials, 68, y, View.INK)
                View.right(screen, tostring(entry.rally), 136, y, View.INK)
            else
                View.text(screen, text("Empty"), 68, y, View.SOFT)
            end
        end
    end
    View.centre(screen, text("WonLost", self.records.wins, self.records.losses), View.CENTRE, 98, View.DIM)
end

--- Opens the screen that waits for the other player on the cable, the cable to be measured again.
function Game:openWaiting()
    self.mode = Game.MODE_WAITING
    self.twoPlayer = true
    self.peerSeen = false
    self.port:reset()
    self.port:forgetMeasure()
    self.port:hello()
end

--- Waits for the other console: says hello every half second; once both are there, the owner of the cable measures it with pings, then picks the seed and the delay, sends the start and opens the match. B leaves and tells the other console.
function Game:tickWaiting(input)
    self:keepMusic(Music.TITLE)
    local port = self.port
    if input.pressed.b then
        port:bye()
        self:effect(Music.BACK)
        self:openTitle()
        return
    end
    if self.clock % HELLO_EVERY == 0 then
        port:hello()
    end
    if not (self.peerSeen and port:leads()) then
        return
    end
    if port:needsPing() and self.clock % PING_EVERY == 0 then
        port:ping(self.clock)
    elseif port:measured() then
        -- self.random is seeded by the console, so only the owner draws the
        -- seed of the match; the other console receives it in the start message.
        local seed = self.random:int(1, SEED_MAX)
        local delay = port:delay()
        if port:sendStart(seed, delay, self.options.speed, self.options.points) then
            self:startLinkedMatch(seed, delay, self.options.speed, self.options.points, port:halfTrip())
        end
    end
end

--- Draws the waiting screen: who it waits for, or that both consoles are connecting.
function Game:drawWaiting(screen)
    View.clear(screen, View.PAPER)
    View.centre(screen, text("TwoPlayers"), View.CENTRE, 10, View.INK)
    if self.peerSeen then
        View.centre(screen, text("Connecting"), View.CENTRE, 50, View.INK)
    else
        View.centre(screen, text("WaitingFor"), View.CENTRE, 42, View.INK)
        View.centre(screen, text("OtherPlayer"), View.CENTRE, 58, View.INK)
    end
    self:drawDemo(screen, DEMO_WAITING_Y)
    View.centre(screen, text("BackHint"), View.CENTRE, 98, View.SOFT)
end
