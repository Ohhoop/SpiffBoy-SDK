-- Plays rounds of Hello SpiffBoy on one console with tests/lib/test_console.lua
-- and checks when the game writes its save: never during a round nor when a
-- round is given up, once when the end of a round is confirmed with a
-- button, and only what changed. It is a model for a test of your own game.

local check = TestConsole.check
local console = TestConsole.start("SpiffBoySDK/Games/HelloSpiffBoy", 7, {})
local game = console.game

--- Plays a round from the title: says hello the given number of times, then waits for the end of the 30 seconds.
local function playRound(hellos)
    console:press("a")
    for _ = 1, hellos do
        console:press("a")
        console:wait(1)
    end
    console:wait(30 * 60)
end

check(console.crash == nil and game.mode == "title", "the game opens on the title")
playRound(5)
check(game.mode == "over" and game.newBest, "the round ends on the end screen with a new best")
check(#console.saves == 0, "nothing is written during a round")
console:wait(120)
check(#console.saves == 0, "nothing is written while the end screen waits")
console:press("a")
check(game.mode == "title" and #console.saves == 1 and console.saves[1].best == 5, "confirming the end screen writes the best count once")
check(console.saves[1].options == nil, "an unchanged music option is not written")

console:press("down")
console:press("a")
check(not game.musicOn and #console.saves == 1, "switching the music off writes nothing")
console:press("up")
playRound(3)
check(game.mode == "over" and not game.newBest, "a lower count is no new best")
console:press("start")
check(#console.saves == 2 and console.saves[2].best == 5 and console.saves[2].options.music == false, "the next confirmed round writes the music option")

console:press("up")
console:press("a")
console:press("a")
console:press("a")
console:press("start")
check(game.mode == "title" and #console.saves == 2, "a round given up with START writes nothing")

playRound(0)
console:press("a")
check(#console.saves == 2, "a round that changed nothing writes nothing")
check(console.crash == nil and console.most < 300, "no crash, every frame under the draw call limit: " .. tostring(console.crash))
