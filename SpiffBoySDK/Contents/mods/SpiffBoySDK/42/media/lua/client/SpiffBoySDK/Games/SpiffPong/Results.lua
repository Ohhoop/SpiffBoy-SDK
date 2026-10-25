-- The end of a match of Spiff-Pong: the result over the final field, then,
-- after a match against the console whose longest rally enters the best
-- scores, the entry of the initials of the player.

require "SpiffBoySDK/Core"

local Game = SpiffBoySDKPongGame
local Pong = SpiffBoySDK.SpiffPong
local Music = Pong.Music
local Records = Pong.Records
local View = Pong.View
local text = Game.text

-- The result ignores the buttons for a moment, so a press of A or START made
-- in the last moments of the match does not skip it at once.
local RESULT_LOCK = 60
local BLINK_TICKS = 16
local LETTER_COUNT = string.len(Records.LETTERS)
local LETTER_GAP = 20
local LETTERS_Y = 62

--- Opens the result of the decided match with the jingle of the winner or the loser; against the console the match is counted in the records, which reach the cartridge when the player confirms the result.
function Game:openResult()
    local match = self.match
    self.mode = Game.MODE_RESULT
    self.resultLock = RESULT_LOCK
    self.won = match.winner == self.mySide
    self.sequencer:stop()
    if self.won then
        self.sequencer:play(Music.WIN)
    else
        self.sequencer:play(Music.LOSE)
    end
    self.rank = nil
    if not self.twoPlayer then
        Records.count(self.records, self.won)
        self.rank = Records.rankOf(self.records, match.longestRally)
        Records.write(self.save, self.records)
    end
end

--- Waits for A or Start once the lock is over, then asks for initials when the rally entered the best scores, or writes the counted match and goes back to the title.
function Game:tickResult(input)
    if self.resultLock > 0 then
        self.resultLock = self.resultLock - 1
        return
    end
    local pressed = input.pressed
    if not (pressed.a or pressed.start) then
        return
    end
    self:effect(Music.CONFIRM)
    if self.rank then
        -- The initials end with one write that also holds the counted match.
        self:openInitials()
        return
    end
    -- A game saves on a press of the player, never on its own: the match
    -- against the console reaches the cartridge now that the player confirms
    -- its result.
    if not self.twoPlayer then
        self:persist()
    end
    self:openTitle()
end

--- Draws the result in a box over the final field: who won, the score, the longest rally and, once the lock is over, a blinking prompt.
function Game:drawResult(screen)
    local match = self.match
    View.field(screen, match, self.digits)
    View.box(screen, 18, 20, 144, 80)
    local verdict = "YouLose"
    if self.won then
        verdict = "YouWin"
    end
    View.centre(screen, text(verdict), View.CENTRE, 24, View.INK)
    View.centre(screen, text("FinalScore", match.score[1], match.score[2]), View.CENTRE, 42, View.DIM)
    View.centre(screen, text("LongestRally", match.longestRally), View.CENTRE, 58, View.DIM)
    if self.resultLock <= 0 and math.floor(self.clock / BLINK_TICKS) % 2 == 0 then
        View.centre(screen, text("PressA"), View.CENTRE, 78, View.INK)
    end
end

--- Opens the entry of the initials on the first letter, every letter on A.
function Game:openInitials()
    self.mode = Game.MODE_INITIALS
    self.letters = { 1, 1, 1 }
    self.letterIndex = 1
end

--- Returns the initials being entered as a text.
function Game:initials()
    local out = ""
    for i = 1, Records.INITIALS_LENGTH do
        local index = self.letters[i]
        out = out .. string.sub(Records.LETTERS, index, index)
    end
    return out
end

--- Applies the input to the initials: up and down change the letter, A goes to the next letter and saves after the last, B goes back one letter.
function Game:tickInitials(input)
    self:keepMusic(Music.TITLE)
    local pressed = input.pressed
    local step = Game.verticalStep(pressed)
    if step ~= 0 then
        local i = self.letterIndex
        -- Up goes forward in the alphabet, down goes back.
        self.letters[i] = Game.wrap(self.letters[i], -step, LETTER_COUNT)
        self:effect(Music.MOVE)
    end
    if pressed.b and self.letterIndex > 1 then
        self.letterIndex = self.letterIndex - 1
        self:effect(Music.BACK)
    elseif pressed.a or pressed.start then
        self:effect(Music.CONFIRM)
        if self.letterIndex < Records.INITIALS_LENGTH then
            self.letterIndex = self.letterIndex + 1
            return
        end
        local rank = Records.insert(self.records, self:initials(), self.match.longestRally)
        Records.write(self.save, self.records)
        self:persist()
        self:openRecords(rank)
    end
end

--- Draws the entry of the initials: the new record, the three letters and a blinking mark under the current one.
function Game:drawInitials(screen)
    View.clear(screen, View.PAPER)
    View.centre(screen, text("NewRecord"), View.CENTRE, 6, View.INK)
    View.centre(screen, text("LongestRally", self.match.longestRally), View.CENTRE, 24, View.DIM)
    View.centre(screen, text("EnterInitials"), View.CENTRE, 42, View.DIM)
    for i = 1, Records.INITIALS_LENGTH do
        local x = View.CENTRE + (i - 2) * LETTER_GAP
        local index = self.letters[i]
        View.centre(screen, string.sub(Records.LETTERS, index, index), x, LETTERS_Y, View.INK)
        if i == self.letterIndex and math.floor(self.clock / BLINK_TICKS) % 2 == 0 then
            View.rect(screen, x - 4, LETTERS_Y + 16, 8, 2, View.INK)
        end
    end
    View.centre(screen, text("InitialsHint"), View.CENTRE, 98, View.SOFT)
end
