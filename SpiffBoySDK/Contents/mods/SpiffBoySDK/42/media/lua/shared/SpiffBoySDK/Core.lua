-- The SpiffBoy SDK keeps everything it shares between its files in one global
-- table, named after the mod, so it never clashes with another mod.
SpiffBoySDK = SpiffBoySDK or {}

-- The id of this mod, as written in its mod.info. A cartridge definition gives
-- it in its `mod` field so the console finds the art and the texts of the game
-- in this mod.
SpiffBoySDK.MOD_ID = "SpiffBoySDK"
