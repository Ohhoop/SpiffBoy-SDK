-- Spiff-Pong: the game class, in a file of its own.
--
-- LOAD ORDER
-- The game loads every Lua file of a mod on its own, shared files first, then
-- client files, each group in alphabetical order of its path, whatever your
-- requires say: Menus.lua loads before Music.lua, Play.lua before View.lua.
-- A require runs a file that has not loaded yet, at once, so a file that reads
-- another file while it loads, such as `local Music = Pong.Music` at its top,
-- must require that file first; otherwise it keeps nil and the game stops the
-- first time it uses it.
-- The class lives here so that Game.lua and the files that add methods to it,
-- Menus, Play and Results, all require it without requiring each other: two
-- files that require each other are an error of the game.

require "SpiffBoySDK/Core"
require "SpiffBoy/Core/GameBase"
require "SpiffBoy/Framework/GameTexts"

-- The global name given as `game` in Definition.lua.
SpiffBoySDKPongGame = SpiffBoyGameBase:derive("SpiffBoySDKPongGame")

local Game = SpiffBoySDKPongGame

-- Every text of the game goes through this function, which picks the language
-- of the player from the Translate folder of the cartridge.
Game.text = SpiffBoy.GameTexts.of("SpiffPong")
