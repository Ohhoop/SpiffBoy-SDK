-- Hello SpiffBoy: the game itself.
--
-- Read this file first if you want to make a cartridge. It shows every piece
-- a game of the SpiffBoy console needs, and nothing more:
--   * a title screen with a small menu (PLAY, MUSIC ON/OFF),
--   * a play screen where Spiffo moves with the arrows,
--   * A says hello: a sound effect, a speech bubble and a counter,
--   * B switches the music on and off, START goes back to the menu,
--   * the best count and the music option are kept in the save of the cartridge,
--   * every text comes from the translation files of the game.
--
-- How the console runs a game
-- ---------------------------
-- The console (the framework) creates the game at each power on, then calls
-- two methods again and again:
--   tick(inputs, tick)  once per fixed step: 60 times per second at normal
--                       game speed, two to six times more when the game runs
--                       fast forward, never while it is paused. All the rules
--                       live here: moving, counting, playing sounds.
--   draw(screen)        whenever the window paints a frame. It only reads the
--                       state and draws it; it never changes the game.
-- Keeping the rules in tick makes the game run the same on a slow computer
-- and a fast one: between two frames the console runs as many ticks as the
-- elapsed time calls for (zero, one or several), so the frame rate never
-- changes the game.
--
-- The screen
-- ----------
-- The screen is 180 x 120 logical pixels and shows only four shades of
-- green-grey, numbered 1 (darkest) to 4 (lightest). Pictures are white masks
-- that the console paints in a shade. A picture in several shades is a
-- "layered sheet": the same cell drawn once per shade (see spiffo.png and
-- docs/FRAMEWORK.md). Each picture, rectangle, layer or letter drawn costs one
-- "draw call" (a space costs none). A frame may make at most 300: the 301st is
-- an error that stops the game. This game makes about 40 at most.
--
-- Exercises: the comments marked "Exercise N" point to the code each exercise
-- of docs/exercises/hello-spiffboy.md asks you to change.

require "SpiffBoySDK/Core"
require "SpiffBoy/Framework/Cartridges"
require "SpiffBoy/Framework/GameTexts"
require "SpiffBoy/Core/GameBase"
require "SpiffBoySDK/Games/HelloSpiffBoy/Music"

-- The game class. `derive` gives it the default behaviour of every game
-- (self.screen, self.random, self.save, self.chip, self.sequencer, persist).
-- Its name must match the `game` field of Definition.lua.
SpiffBoySDKHelloGame = SpiffBoyGameBase:derive("SpiffBoySDKHelloGame")

local Music = SpiffBoySDK.HelloSpiffBoy.Music

-- gameText(key, ...) returns the text of a key of Translate/<LANG>.json in the
-- language of the player (English when the key is missing in that language),
-- with %1, %2... replaced by the arguments. Never write a text in the code:
-- always go through gameText so the game can be translated.
local gameText = SpiffBoy.GameTexts.of("HelloSpiffBoy")

-- The four shades of the screen, darkest first. Each is a table { r, g, b }.
local SHADES = SpiffBoy.Cartridges.SHADES

-- The head of Spiffo: a 16 x 16 cell. spiffo.png holds three cells side by
-- side (idle, blinking, saying hello), each repeated in four rows, one per shade.
local CELL = 16
local FRAME_IDLE = 0
local FRAME_BLINK = 1
local FRAME_HELLO = 2
-- The fur of Spiffo is shade 4, the same shade as the background. Drawing only
-- the layers 1, 2 and 3 lets the background show through and saves one draw
-- call per head. Draw { 1, 2, 3, 4 } if Spiffo ever walks over something else.
local HEAD_SHADES = { 1, 2, 3 }

-- Pixels Spiffo moves per tick while an arrow is held (60 ticks per second).
local SPEED = 1 -- Exercise 1: try changing SPEED.

-- The playfield: between the line of counters at the top and the hint at the bottom.
local PLAY_TOP = 18
local PLAY_BOTTOM = 101

-- How long things last, in ticks (60 ticks = 1 second).
local HELLO_TICKS = 40
local BLINK_TICKS = 8
local BLINK_GAP_MIN = 90
local BLINK_GAP_MAX = 240
local HINT_TICKS = 120
local BOB_TICKS = 30

-- The counter stops at 9999 so its text always fits in the top line.
local MAX_COUNT = 9999

-- The two screens of the game.
local MODE_TITLE = "title"
local MODE_PLAY = "play"

-- The entries of the title menu, top to bottom.
local MENU_PLAY = 1
local MENU_MUSIC = 2
local MENU_SIZE = 2
local MENU_Y = 54
local MENU_STEP = 20
local MENU_BAR_WIDTH = 104

--- Returns the red, green and blue of a shade of the screen, from 1 (darkest) to 4 (lightest).
local function ink(index)
    local shade = SHADES[index]
    return shade.r, shade.g, shade.b
end

--- Returns a value kept between a low and a high bound.
local function clamp(value, low, high)
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

--- Returns the best count held by the save, or 0 when the save holds none.
local function readBest(save)
    -- A save can come from an older version of the game, or be empty on a new
    -- cartridge: check the type of every value read from it.
    local best = save.best
    if type(best) ~= "number" or best < 0 then
        return 0
    end
    return math.min(math.floor(best), MAX_COUNT)
end

--- Returns true when the save asks for the music, which a new cartridge does.
local function readMusic(save)
    -- A new cartridge has no `music` entry yet: only an explicit false turns it off.
    return save.music ~= false
end

--- Prepares the game at power on: loads the art, reads the save and shows the title screen.
function SpiffBoySDKHelloGame:init()
    -- context.art(name) loads name.png from the art folder of the definition.
    -- Load art once here, never in draw.
    self.spiffo = self.context.art("spiffo")
    -- self.save is the table stored on the cartridge item. It survives power
    -- off and follows the cartridge from console to console.
    self.best = readBest(self.save)
    self.musicOn = readMusic(self.save)
    -- Exercise 5: read your new saved value here.
    self.ticks = 0
    self.blinkTicks = 0
    -- self.random is seeded by the console. Never use math.random or ZombRand
    -- in a game: a seeded generator makes a run repeatable, which the test
    -- robot relies on to compare two runs.
    self.nextBlink = self.random:int(BLINK_GAP_MIN, BLINK_GAP_MAX)
    self:enterTitle()
    self:applyMusic()
end

--- Shows the title screen with the cursor on PLAY.
function SpiffBoySDKHelloGame:enterTitle()
    self.mode = MODE_TITLE
    self.selection = MENU_PLAY
end

--- Starts a visit of the play screen: the counter at zero and Spiffo in the middle of the playfield.
function SpiffBoySDKHelloGame:enterPlay()
    self.mode = MODE_PLAY
    self.count = 0
    self.x = math.floor((self.screen.width - CELL) / 2)
    self.y = math.floor((PLAY_TOP + PLAY_BOTTOM - CELL) / 2)
    self.helloTicks = 0
    -- Exercise 6: place the follower here.
end

--- Plays the theme when the music is on, stops the music when it is off.
function SpiffBoySDKHelloGame:applyMusic()
    if self.musicOn then
        -- play() starts the tune from its beginning; the theme loops by itself.
        self.sequencer:play(Music.THEME)
    else
        self.sequencer:stop()
    end
end

--- Switches the music on or off and keeps the choice in the save.
function SpiffBoySDKHelloGame:toggleMusic()
    self.musicOn = not self.musicOn
    self.save.music = self.musicOn
    -- persist() writes self.save on the cartridge. It costs a write of the
    -- item (and a message to the server in multiplayer), so call it when
    -- something worth keeping changed, never every tick.
    self:persist()
    self:applyMusic()
    self.sequencer:effect(Music.TOGGLE)
end

--- Advances the game by one step of 1/60 second with the buttons of the player.
function SpiffBoySDKHelloGame:tick(inputs, tick)
    -- inputs[1] holds the buttons of the player holding the console.
    local input = inputs[1]
    self.ticks = self.ticks + 1
    self:tickBlink()
    if self.mode == MODE_TITLE then
        self:tickTitle(input)
    else
        self:tickPlay(input)
    end
end

--- Makes Spiffo blink now and then, at random moments.
function SpiffBoySDKHelloGame:tickBlink()
    if self.blinkTicks > 0 then
        self.blinkTicks = self.blinkTicks - 1
        return
    end
    self.nextBlink = self.nextBlink - 1
    if self.nextBlink <= 0 then
        self.blinkTicks = BLINK_TICKS
        self.nextBlink = self.random:int(BLINK_GAP_MIN, BLINK_GAP_MAX)
    end
end

--- Moves the cursor of the title menu and runs the entry chosen with A or START.
function SpiffBoySDKHelloGame:tickTitle(input)
    -- `pressed` is true only on the tick a button goes down: one press, one
    -- move of the cursor. `held` stays true as long as the button is down,
    -- which suits movement (see tickPlay), not menus.
    local pressed = input.pressed
    if pressed.up then
        -- Wrap from the first entry to the last. In the Lua of the game,
        -- `%` keeps the sign of the left side (-1 % 2 is -1, not 1), so add
        -- MENU_SIZE before taking the remainder to keep it positive.
        self.selection = (self.selection - 2 + MENU_SIZE) % MENU_SIZE + 1
        self.sequencer:effect(Music.MOVE)
    elseif pressed.down then
        self.selection = self.selection % MENU_SIZE + 1
        self.sequencer:effect(Music.MOVE)
    end
    if pressed.a or pressed.start then
        if self.selection == MENU_PLAY then
            self.sequencer:effect(Music.SELECT)
            self:enterPlay()
        else
            self:toggleMusic()
        end
    end
end

--- Moves Spiffo with the arrows held, says hello on A, switches the music on B and goes back to the title on START.
function SpiffBoySDKHelloGame:tickPlay(input)
    local pressed = input.pressed
    -- Exercise 7: START opens a pause screen instead of leaving.
    if pressed.start then
        self:leavePlay()
        return
    end
    -- axes() turns the held arrows into a direction: -1, 0 or 1 on each axis.
    local dx, dy = input:axes()
    self:moveSpiffo(dx * SPEED, dy * SPEED)
    if pressed.a then
        self:sayHello()
    end
    if pressed.b then
        self:toggleMusic()
    end
    if self.helloTicks > 0 then
        self.helloTicks = self.helloTicks - 1
    end
    -- Exercise 6: move the follower toward Spiffo here.
end

--- Moves Spiffo by the given pixels, kept inside the playfield.
function SpiffBoySDKHelloGame:moveSpiffo(dx, dy)
    -- Exercise 2: make Spiffo wrap around the edges instead of stopping.
    self.x = clamp(self.x + dx, 0, self.screen.width - CELL)
    self.y = clamp(self.y + dy, PLAY_TOP, PLAY_BOTTOM - CELL)
end

--- Counts one more hello, opens the mouth of Spiffo, shows the bubble and plays the hello effect.
function SpiffBoySDKHelloGame:sayHello()
    self.count = math.min(self.count + 1, MAX_COUNT)
    self.helloTicks = HELLO_TICKS
    -- Exercise 3: pick the text of the bubble here.
    -- Exercise 4: play a different effect every tenth hello.
    self.sequencer:effect(Music.HELLO)
    -- The best count shows at once, but reaches the save in leavePlay.
    if self.count > self.best then
        self.best = self.count
    end
end

--- Writes a new best count in the save and goes back to the title screen.
function SpiffBoySDKHelloGame:leavePlay()
    -- One write per visit, and only when the best changed.
    if self.best ~= self.save.best then
        self.save.best = self.best
        self:persist()
    end
    -- Exercise 5: add this visit to a saved total here.
    self:enterTitle()
end

--- Returns the cell of Spiffo to draw: mouth open while the bubble shows, eyes shut while blinking, idle otherwise.
function SpiffBoySDKHelloGame:frame()
    if self.mode == MODE_PLAY and self.helloTicks > 0 then
        return FRAME_HELLO
    end
    if self.blinkTicks > 0 then
        return FRAME_BLINK
    end
    return FRAME_IDLE
end

--- Draws the head of Spiffo in the given cell at a position of the screen.
function SpiffBoySDKHelloGame:drawSpiffo(screen, frame, x, y)
    -- layers(texture, left of the cell, width, height, x, y, shades) draws
    -- one cell of a layered sheet, one draw call per shade listed.
    screen:layers(self.spiffo, frame * CELL, CELL, CELL, x, y, HEAD_SHADES)
end

--- Draws the current screen of the game.
function SpiffBoySDKHelloGame:draw(screen)
    -- The game must paint the whole 180 x 120 area on every frame: clear fills
    -- it with the lightest shade in one draw call, the rest is drawn on top.
    screen:clear(ink(4))
    if self.mode == MODE_TITLE then
        self:drawTitle(screen)
    else
        self:drawPlay(screen)
    end
end

--- Draws the title, a bobbing Spiffo, the menu with its cursor bar and the best count.
function SpiffBoySDKHelloGame:drawTitle(screen)
    local centre = math.floor(screen.width / 2)
    -- textCentre(text, centre x, top y, r, g, b): one draw call per letter.
    screen:textCentre(gameText("Title"), centre, 6, ink(1))
    -- The head goes up and down one pixel every half second.
    local bob = math.floor(self.ticks / BOB_TICKS) % 2
    self:drawSpiffo(screen, self:frame(), centre - CELL / 2, 28 + bob)
    local labels = { gameText("Play"), self.musicOn and gameText("MusicOn") or gameText("MusicOff") }
    for i = 1, MENU_SIZE do
        local y = MENU_Y + (i - 1) * MENU_STEP
        if i == self.selection then
            -- The chosen entry: light letters on a dark bar.
            screen:rect(centre - MENU_BAR_WIDTH / 2, y, MENU_BAR_WIDTH, screen:lineHeight(), ink(1))
            screen:textCentre(labels[i], centre, y, ink(4))
        else
            screen:textCentre(labels[i], centre, y, ink(2))
        end
    end
    -- Exercise 5: show your saved total under the best count.
    screen:textCentre(gameText("Best", self.best), centre, 100, ink(2))
end

--- Draws the counters, the playfield with Spiffo and its bubble, and the hint line.
function SpiffBoySDKHelloGame:drawPlay(screen)
    local width = screen.width
    screen:text(gameText("Count", self.count), 2, 1, ink(1))
    screen:textRight(gameText("Best", self.best), width - 2, 1, ink(1))
    -- Two thin lines frame the playfield.
    screen:rect(0, PLAY_TOP - 1, width, 1, ink(2))
    screen:rect(0, PLAY_BOTTOM, width, 1, ink(2))
    -- Exercise 6: draw the follower here, before Spiffo so Spiffo stays in front.
    self:drawSpiffo(screen, self:frame(), self.x, self.y)
    if self.helloTicks > 0 then
        self:drawBubble(screen)
    end
    -- The hint switches between the buttons and START every two seconds.
    local hint = "HintButtons"
    if math.floor(self.ticks / HINT_TICKS) % 2 == 1 then
        hint = "HintStart"
    end
    screen:textCentre(gameText(hint), math.floor(width / 2), PLAY_BOTTOM + 2, ink(2))
end

--- Draws the speech bubble above Spiffo, or below it when Spiffo stands at the top of the playfield.
function SpiffBoySDKHelloGame:drawBubble(screen)
    local text = gameText("Hello")
    -- Measure the text so the bubble fits any language.
    local w = screen:textWidth(text) + 6
    -- lineHeight() is the height of a line of text in the current language.
    local h = screen:lineHeight() + 2
    local x = clamp(math.floor(self.x + CELL / 2 - w / 2), 0, screen.width - w)
    local y = self.y - h - 1
    if y < PLAY_TOP then
        y = self.y + CELL + 1
    end
    -- A dark box with a light inside makes a one pixel border: two draw calls.
    screen:rect(x, y, w, h, ink(1))
    screen:rect(x + 1, y + 1, w - 2, h - 2, ink(4))
    screen:text(text, x + 3, y + 1, ink(1))
end
