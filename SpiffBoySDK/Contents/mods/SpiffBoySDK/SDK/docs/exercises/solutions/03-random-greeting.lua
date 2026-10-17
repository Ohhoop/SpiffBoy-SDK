-- Solution of exercise 3: a random greeting.
-- Files: lua/shared/SpiffBoySDK/Games/HelloSpiffBoy/Translate/EN.json
--        lua/client/SpiffBoySDK/Games/HelloSpiffBoy/Game.lua
--
-- This is an excerpt, not a file to load: copy each part over the matching
-- part of the files.

-- Part 1, EN.json: add two keys inside the "UI" section, next to "Hello".
--
--     "Hi": "HI THERE!",
--     "Hey": "HEY!",
--
-- The key is the short name the code uses; the text is what the player reads.
-- Every other language file can translate the same keys later.

-- Part 2, near the top of Game.lua, under the other constants:
-- the keys the bubble picks from.
local GREETINGS = { "Hello", "Hi", "Hey" }

-- Part 3, Game.lua: replace the whole function sayHello.

--- Counts one more hello, picks a greeting, opens the mouth of Spiffo, shows the bubble and plays the hello effect.
function SpiffBoySDKHelloGame:sayHello()
    self.count = math.min(self.count + 1, MAX_COUNT)
    self.helloTicks = HELLO_TICKS
    -- self.random is the generator the console seeded for this run.
    -- int(1, 3) returns 1, 2 or 3, both ends included. The choice is made
    -- here, in tick, and kept in the state: draw only reads it.
    self.greeting = GREETINGS[self.random:int(1, #GREETINGS)]
    self.sequencer:effect(Music.HELLO)
    if self.count > self.best then
        self.best = self.count
    end
end

-- Part 4, Game.lua: in drawBubble, replace the first line
--     local text = gameText("Hello")
-- with:
    local text = gameText(self.greeting)
-- The bubble measures its text, so a longer greeting gets a wider bubble.
