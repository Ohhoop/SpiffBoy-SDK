local LUA_ROOTS, MOD_FOLDERS = ...

ROBOT = { nowMs = 1000 }

luautils = {
    stringEnds = function(s, suffix) return string.sub(s, -string.len(suffix)) == suffix end,
    round = function(v) return v end,
}
keyBinding = {}
Keyboard = { KEY_NONE = 0, KEY_ESCAPE = 1, KEY_W = 17, KEY_S = 31, KEY_A = 30, KEY_D = 32, KEY_L = 38, KEY_P = 25, KEY_SPACE = 57, KEY_CAPITAL = 58 }
KeybindId = { RUN = "Run" }
local keyOf = { SB_Up = 17, SB_Down = 31, SB_Left = 30, SB_Right = 32, SB_A = 38, SB_B = 25, SB_Start = 57, Run = 42 }
local core = {
    getKey = function(_, id) return keyOf[id] or 0 end,
    getAltKey = function() return 0 end,
    getScreenWidth = function() return 1920 end,
    getScreenHeight = function() return 1080 end,
}
function getCore() return core end
function isKeyDown() return false end
function getTimestampMs() return ROBOT.nowMs end
local gameTime = { getTrueMultiplier = function() return 1 end, getMultiplier = function() return 1 end, getWorldAgeHours = function() return 0 end }
function getGameTime() return gameTime end
function isClient() return false end
function isServer() return false end
function isGamePaused() return false end
Events = setmetatable({}, { __index = function(t, name)
    local event = { handlers = {} }
    event.Add = function(fn) event.handlers[#event.handlers + 1] = fn end
    event.Remove = function() end
    rawset(t, name, event)
    return event
end })
Translator = { getLanguage = function() return { name = function() return "EN" end } end }
SandboxVars = { SpiffBoy = { PlayingEasesMood = true, NoiseAttractsZombies = true, BatteriesDrain = true, Dismantling = true, CartridgeLoot = 3, LinkCableLoot = 3, ConsoleCartridgeChance = 50, ZombiesCarryCartridges = true, OthersHearConsole = true } }
function getModFileReader(modId, path, create)
    local folder = MOD_FOLDERS[modId]
    if not folder then
        return nil
    end
    local file = io.open(folder .. "/" .. path, "rb")
    if not file then
        return nil
    end
    return {
        readLine = function()
            local line = file:read("*l")
            if line then
                line = string.gsub(line, "\r$", "")
            end
            return line
        end,
        close = function() file:close() end,
    }
end
function getModInfoByID() return { getVersionDir = function() return "MOD" end } end
function ROBOT.texture(path)
    return { path = path, isReady = function() return true end, getWidth = function() return 40 end, getHeight = function() return 6 end, reloadFromFile = function() end }
end
Texture = { getSharedTexture = function(path) return ROBOT.texture(path) end, new = function(path) return ROBOT.texture(path) end }
function getTexture(path) return ROBOT.texture(path) end
UIManager = { getMillisSinceLastRender = function() return 1000 / 60 end }
local function newEmitter()
    local refs = 0
    return {
        playClip = function() refs = refs + 1; return refs end,
        set3D = function() end, setPos = function() end, setPitch = function() end, setVolume = function() end,
        tick = function() end, isPlaying = function() return true end, stopSound = function() end, stopAll = function() end,
    }
end
FMODSoundEmitter = { new = newEmitter }
GameSounds = { getSound = function(name) return { getRandomClip = function() return name end } end }
function getSoundManager() return { getSoundVolume = function() return 1 end, unregisterEmitter = function() end } end
function sendClientCommand() end
function sendServerCommand() end
function ZombRand() return 0 end
function instanceof() return true end
function getItemNameFromFullType(t) return t end

ROBOT.missingTexts = 0
function getText(key, ...)
    local text = ROBOT.texts[key]
    if not text then
        ROBOT.missingTexts = ROBOT.missingTexts + 1
        return key
    end
    local args = { ... }
    for i = 1, #args do
        text = string.gsub(text, "%%" .. i, function() return tostring(args[i]) end)
    end
    return text
end

local loaded = {}
require = function(name)
    if loaded[name] then
        return
    end
    loaded[name] = true
    for _, root in ipairs(LUA_ROOTS) do
        for _, folder in ipairs({ "shared", "client", "server" }) do
            local fn = loadfile(root .. "/" .. folder .. "/" .. name .. ".lua")
            if fn then
                fn()
                return
            end
        end
    end
end

next = nil
local rawChar = string.char
string.char = function(...)
    local out = {}
    for i, code in ipairs({ ... }) do
        if code > 255 then out[i] = "?" else out[i] = rawChar(code) end
    end
    return table.concat(out)
end

require "SpiffBoy/Core/Core"
require "SpiffBoy/Core/Commands"
require "SpiffBoy/Core/SaveData"
require "SpiffBoy/Core/KeyBinds"
require "SpiffBoy/Framework/Cartridges"
require "SpiffBoy/Core/Chip"
require "SpiffBoy/Core/Tunes"
require "SpiffBoy/Core/Sequencer"
require "SpiffBoy/Core/Clock"
require "SpiffBoy/Core/Textures"
require "SpiffBoy/Core/PixelFont"
require "SpiffBoy/Core/Runtime"
require "SpiffBoy/Core/Input"
require "SpiffBoy/Core/GameBase"
