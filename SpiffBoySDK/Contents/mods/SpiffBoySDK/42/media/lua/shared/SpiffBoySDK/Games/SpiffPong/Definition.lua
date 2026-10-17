-- Spiff-Pong, the complete example cartridge of the SpiffBoy SDK.
--
-- A cartridge is made of five kinds of files, each in the folder the engine
-- reads it from:
--   * this Definition.lua (shared), which tells the console the cartridge exists;
--   * the game itself (client), under lua/client/SpiffBoySDK/Games/SpiffPong/,
--     split into small files by role;
--   * its texts, one JSON file per language, in the Translate folder next to
--     this file;
--   * its art in media/ui/SpiffBoySDK/Games/SpiffPong/: white masks for the
--     game, and label.png, a colour picture for the label of the cartridge;
--   * the cartridge item in media/scripts/SpiffBoySDK/SpiffPong.txt.
--
-- Shared files load before client files, so the definition is known by the
-- time the game file asks for its texts.

require "SpiffBoySDK/Core"
require "SpiffBoy/Framework/Cartridges"

SpiffBoy.Cartridges.register({
    -- The version of the SpiffBoy framework this game is written for. A SpiffBoy
    -- too old to know it refuses the cartridge with a clear error.
    api = 1,
    -- The id identifies the game: its texts and its tunes are looked up by it,
    -- and by convention its folders carry the same name.
    id = "SpiffPong",
    -- The full type of the item that carries the game (module.item).
    item = "SpiffBoySDK.Cartridge_SpiffPong",
    -- The title printed on the label when the art holds no label.png.
    title = "Spiff-Pong",
    -- The mod that holds the art and the texts of the game.
    mod = SpiffBoySDK.MOD_ID,
    -- The global name of the game class, defined in the client Game.lua.
    game = "SpiffBoySDKPongGame",
    art = "media/ui/SpiffBoySDK/Games/SpiffPong/",
    texts = "media/lua/shared/SpiffBoySDK/Games/SpiffPong/Translate/",
    -- A weight of 0 keeps this example out of the loot of the world.
    loot = { weight = 0 },
})
