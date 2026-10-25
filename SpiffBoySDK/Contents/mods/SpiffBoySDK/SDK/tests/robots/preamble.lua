local LUA_ROOTS, MOD_FOLDERS, LANGUAGE, MOD_FILES = ...

ROBOT = { nowMs = 1000, warnings = {}, loadFailure = nil }

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
Translator = { getLanguage = function() return { name = function() return LANGUAGE end } end }
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
function getModInfoByID(modId)
    local folder = MOD_FOLDERS[modId]
    if not folder then
        return nil
    end
    return { getVersionDir = function() return folder end }
end
function ROBOT.texture(path)
    return { path = path, isReady = function() return true end, getWidth = function() return 40 end, getHeight = function() return 6 end, reloadFromFile = function() end }
end
local function shortPath(path)
    for _, folder in pairs(MOD_FOLDERS) do
        if string.sub(path, 1, string.len(folder) + 1) == folder .. "/" then
            return string.sub(path, string.len(folder) + 2)
        end
    end
    return path
end
local filesByLowerPath = nil

--- Returns the path of the file of the mods that has the given path in another letter case, or nil.
local function otherCase(path)
    if not filesByLowerPath then
        filesByLowerPath = {}
        for file, _ in pairs(MOD_FILES) do
            filesByLowerPath[string.lower(file)] = file
        end
    end
    return filesByLowerPath[string.lower(path)]
end

--- Returns the texture of a file of a mod, or nil when no file of the mods has exactly that path, letter case included; a file found in another letter case is named in ROBOT.warnings.
local function fileTexture(path)
    if not MOD_FILES[path] then
        local found = otherCase(path)
        if found then
            ROBOT.warnings[#ROBOT.warnings + 1] = "picture " .. shortPath(path) .. " exists as " .. shortPath(found) .. ": give its name with the letter case of the file, which Linux and the Steam Deck need"
        end
        return nil
    end
    return ROBOT.texture(shortPath(path))
end
Texture = { getSharedTexture = fileTexture, new = fileTexture }
getTexture = fileTexture
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
function instanceof() return true end
function getItemNameFromFullType(t) return t end
ResourceLocation = { of = function(name) return name end }
ItemTag = { get = function(name) return name end }

--- Returns the script manager of the robot, which finds the items of the scripts of the mod in ROBOT.itemScripts.
function getScriptManager()
    return {
        FindItem = function(_, fullType)
            local tags = ROBOT.itemScripts[fullType]
            if not tags then
                return nil
            end
            return {
                hasTag = function(_, tag)
                    for _, held in ipairs(tags) do
                        if held == tag then
                            return true
                        end
                    end
                    return false
                end,
            }
        end,
    }
end

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
            local path = root .. "/" .. folder .. "/" .. name .. ".lua"
            local fn, syntax = loadfile(path)
            if fn == nil and syntax ~= nil and not string.find(syntax, "cannot open", 1, true) then
                ROBOT.loadFailure = ROBOT.loadFailure or (folder .. "/" .. name .. ".lua")
                error(syntax, 0)
            end
            if fn then
                if not MOD_FILES[path] then
                    ROBOT.warnings[#ROBOT.warnings + 1] = "require(\"" .. name .. "\") finds " .. tostring(otherCase(path)) .. " only in another letter case: Linux and the Steam Deck do not find it"
                end
                local ok, problem = pcall(fn)
                if not ok then
                    ROBOT.loadFailure = ROBOT.loadFailure or (folder .. "/" .. name .. ".lua")
                    error(problem, 0)
                end
                return
            end
        end
    end
    local first = string.match(name, "^([^/]+)/")
    if first and ROBOT.namespaces and ROBOT.namespaces[first] then
        ROBOT.warnings[#ROBOT.warnings + 1] = "require(\"" .. name .. "\") finds no file in lua/shared, lua/client or lua/server of the mod: check the path and its letter case"
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

--- Returns the code points of a text of this interpreter, held as UTF-8 bytes where the game holds UTF-16 units, with the byte where each starts, as PixelFont.decode returns them in the game.
local function decodeUtf8(str)
    local codes, starts = {}, {}
    local i, length = 1, string.len(str)
    while i <= length do
        local first = string.byte(str, i)
        local code, size = first, 1
        if first >= 0xF0 then
            code, size = first % 0x08, 4
        elseif first >= 0xE0 then
            code, size = first % 0x10, 3
        elseif first >= 0xC0 then
            code, size = first % 0x20, 2
        end
        for k = 1, size - 1 do
            code = code * 64 + (string.byte(str, i + k) or 0x80) % 64
        end
        codes[#codes + 1] = code
        starts[#starts + 1] = i
        i = i + size
    end
    return codes, starts
end
SpiffBoy.PixelFont.decode = decodeUtf8
require "SpiffBoy/Core/Runtime"
require "SpiffBoy/Core/Input"
require "SpiffBoy/Core/GameBase"
require "SpiffBoy/Core/GameErrors"
require "SpiffBoy/Framework/CartridgeTags"

local FAILING_WARNINGS = { "[SB-ART-MISSING]", "[SB-TEXT-MISSING]", "[SB-REG-ITEM]", "[SB-REG-TAG]" }
local log = SpiffBoy.log

--- Writes a line of SpiffBoy in the output and keeps it in ROBOT.warnings when it reports missing art or a missing text.
SpiffBoy.log = function(message)
    local text = tostring(message)
    for _, prefix in ipairs(FAILING_WARNINGS) do
        if string.sub(text, 1, string.len(prefix)) == prefix then
            ROBOT.warnings[#ROBOT.warnings + 1] = text
        end
    end
    log(message)
end

--- Returns the place of a line of Lua as a path from its lua folder and a line number.
local function placeOf(info)
    local source = string.gsub(info.source, "^@", "")
    local fromLua = string.match(source, "/(lua/.*)$")
    return (fromLua or source) .. ":" .. info.currentline
end

local raise = SpiffBoy.GameErrors.raise

--- Raises a coded error of SpiffBoy; a save without a button press also names the line of the game that called persist.
SpiffBoy.GameErrors.raise = function(code, detail)
    if code == "SB-SAVE-PRESS" then
        local caller = debug.getinfo(3, "Sl")
        if caller then
            detail = detail .. ", persist called at " .. placeOf(caller)
        end
    end
    raise(code, detail)
end

local MOD_SOURCE = "@" .. LUA_ROOTS[1] .. "/"

--- Returns the first line of Lua at or above the given level of the stack that belongs to a file, past the tail calls that left no line.
local function fileCallerAt(level)
    local info = debug.getinfo(level, "Sl")
    while info and string.sub(info.source, 1, 1) ~= "@" do
        level = level + 1
        info = debug.getinfo(level, "Sl")
    end
    return info
end

--- Returns the given function made to stop the game with the error SB-REPEAT, naming the function and the line, when the code of the mod calls it; SpiffBoy itself still gets the function.
local function refusedToGames(name, original)
    return function(...)
        local caller = fileCallerAt(3)
        if caller and string.sub(caller.source, 1, string.len(MOD_SOURCE)) == MOD_SOURCE then
            SpiffBoy.GameErrors.raise("SB-REPEAT", name .. " called at " .. placeOf(caller) .. " gives other values on every run and in every copy of the game")
        end
        return original(...)
    end
end
math.random = refusedToGames("math.random", math.random)
math.randomseed = refusedToGames("math.randomseed", math.randomseed)
ZombRand = refusedToGames("ZombRand", function() return 0 end)
os.time = refusedToGames("os.time", os.time)
os.clock = refusedToGames("os.clock", os.clock)
os.date = refusedToGames("os.date", os.date)
getTimestampMs = refusedToGames("getTimestampMs", getTimestampMs)
