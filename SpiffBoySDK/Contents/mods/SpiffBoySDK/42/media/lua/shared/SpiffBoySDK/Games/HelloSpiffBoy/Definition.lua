-- Hello SpiffBoy: the smallest complete cartridge of the SpiffBoy SDK.
--
-- This file registers the cartridge with the console. It lives in the
-- `shared` folder because both sides read the definitions: the server to put
-- cartridges in the loot, the client to find the game, its art and its texts.
-- Shared files load before client files, so nothing else has to require
-- this one.

-- Core.lua defines SpiffBoySDK.MOD_ID, the id of this mod.
require "SpiffBoySDK/Core"
-- Cartridges.lua is the registry of the console. Requiring it makes sure it
-- exists before we register into it.
require "SpiffBoy/Framework/Cartridges"

SpiffBoy.Cartridges.register({
    -- The version of the SpiffBoy framework this game is written for. A SpiffBoy
    -- too old to know it refuses the cartridge with a clear error.
    api = 1,
    -- The id identifies the game: gameText and the tunes are looked up by it,
    -- and by convention its folders carry the same name.
    id = "HelloSpiffBoy",
    -- The full type of the cartridge item, defined in scripts/SpiffBoySDK/HelloSpiffBoy.txt.
    item = "SpiffBoySDK.Cartridge_HelloSpiffBoy",
    -- The title printed on a paper label when the art folder holds no label.png.
    title = "Hello SpiffBoy",
    -- The mod that holds the art and the texts of the game.
    mod = SpiffBoySDK.MOD_ID,
    -- The name of the global game class, defined in the client file Game.lua.
    game = "SpiffBoySDKHelloGame",
    -- The folder of the art: spiffo.png and label.png.
    art = "media/ui/SpiffBoySDK/Games/HelloSpiffBoy/",
    -- The folder of the texts: one JSON file per language.
    texts = "media/lua/shared/SpiffBoySDK/Games/HelloSpiffBoy/Translate/",
    -- A weight of 0 keeps this example out of the loot of the world.
    loot = { weight = 0 },
})
