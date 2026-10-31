local LUA_ROOTS, MOD_FOLDERS, LANGUAGE, MOD_FILES = ...

ROBOT = { nowMs = 1000, warnings = {}, warned = {}, loadFailure = nil, language = LANGUAGE, frameTexts = {}, playedTunes = {}, askedTexts = {} }

--- Adds a warning to ROBOT.warnings the first time its key is met for the game played.
function ROBOT.warnOnce(key, text)
    if not ROBOT.warned[key] then
        ROBOT.warned[key] = true
        ROBOT.warnings[#ROBOT.warnings + 1] = text
    end
end

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
    if not folder or not MOD_FILES[folder .. "/" .. path] then
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
    return { getVersionDir = function() return folder end, getModVersion = function() return "test" end }
end
--- Returns the texture of the robot for a file of a mod: its path from the mod folder, the full path of its file, and the width and height of the picture, read once when first asked.
function ROBOT.texture(path, file)
    local width, height = nil, nil
    local function size()
        if not width then
            width, height = ROBOT.imageSize(file)
        end
        return width, height
    end
    return {
        path = path, file = file, isReady = function() return true end, reloadFromFile = function() end,
        getWidth = function() return (size()) end,
        getHeight = function() return select(2, size()) end,
    }
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
    return ROBOT.texture(shortPath(path), path)
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
require "SpiffBoy/Framework/GameTexts"
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

local FAILING_WARNINGS = { "[SB-ART-MISSING]", "[SB-TEXT-MISSING]", "[SB-REG-ITEM]", "[SB-REG-TAG]", "[SB-GLYPH]", "[SB-REG-VOICES]" }
local NOTED_WARNINGS = { "[SB-SAVE-OFTEN]" }
local log = SpiffBoy.log

--- Writes a line of SpiffBoy in the output and keeps it in ROBOT.warnings when it reports missing art, a missing text, an item script, a missing letter of the font or a tune; a warning on the pace of the saves is kept in ROBOT.notedWarning instead, its code and detail only, as a note that fails nothing, the robot playing faster than a player.
SpiffBoy.log = function(message)
    local text = tostring(message)
    for _, prefix in ipairs(NOTED_WARNINGS) do
        if string.sub(text, 1, string.len(prefix)) == prefix then
            ROBOT.notedWarning = ROBOT.notedWarning or (string.match(text, "^(.-)%. Fix:") or text)
            return
        end
    end
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

--- Returns the first line of Lua at or above the given level of the stack that belongs to a file, past the functions of C and the tail calls that left no line, and true when a tail call was passed.
local function fileCallerAt(level)
    local info = debug.getinfo(level, "Sl")
    local tail = false
    while info and string.sub(info.source, 1, 1) ~= "@" do
        tail = tail or info.what == "tail"
        level = level + 1
        info = debug.getinfo(level, "Sl")
    end
    return info, tail
end

--- Returns where a call to the named function was made: at the line of the call, or, for a tail call, which keeps no line, in a return of a function called at the given line.
local function callPlace(name, info, tail)
    if tail then
        return "in a return " .. name .. "(...) of a function called at " .. placeOf(info) .. ", a tail call that keeps no line of its own,"
    end
    return "at " .. placeOf(info)
end

local raise = SpiffBoy.GameErrors.raise

--- Raises a coded error of SpiffBoy; a save without a button press also names the line of the game that called persist.
SpiffBoy.GameErrors.raise = function(code, detail)
    if code == "SB-SAVE-PRESS" then
        local caller, tail = fileCallerAt(4)
        if caller then
            detail = detail .. ", persist called " .. callPlace("self:persist", caller, tail)
        end
    end
    raise(code, detail)
end

local MOD_SOURCE = "@" .. LUA_ROOTS[1] .. "/"

--- Returns the given function made to stop the game with the error SB-REPEAT, naming the function and the line, when the code of the mod calls it; SpiffBoy itself still gets the function.
local function refusedToGames(name, original)
    return function(...)
        local caller, tail = fileCallerAt(3)
        if caller and string.sub(caller.source, 1, string.len(MOD_SOURCE)) == MOD_SOURCE then
            SpiffBoy.GameErrors.raise("SB-REPEAT", name .. " called " .. callPlace(name, caller, tail) .. " gives other values on every run and in every copy of the game")
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

--- Returns the given texture loader made to warn once, naming the line, when the code of the mod calls it instead of self.context.art; SpiffBoy itself loads its art through it.
local function watchedArtLoader(name, original)
    return function(...)
        local caller, tail = fileCallerAt(3)
        if caller and string.sub(caller.source, 1, string.len(MOD_SOURCE)) == MOD_SOURCE then
            ROBOT.warnOnce(name, name .. " called " .. callPlace(name, caller, tail) .. ": the game may show a picture of Project Zomboid with the same name; load the pictures of the game with self.context.art (docs/03-screen-and-art.md, The art folder)")
        end
        return original(...)
    end
end
getTexture = watchedArtLoader("getTexture", getTexture)
Texture = {
    getSharedTexture = watchedArtLoader("Texture.getSharedTexture", Texture.getSharedTexture),
    new = watchedArtLoader("Texture.new", Texture.new),
}

--- Forgets the texts drawn in the frame, before a new frame is drawn.
function ROBOT.newFrame()
    ROBOT.frameTexts = {}
end

local inkByCell = {}

--- Returns the box of the pixels a cell of a page of the pixel font sets, as its left, top, right and bottom edges inside the cell, read once, or nil for a cell that sets none.
local function cellInk(page, cellX, cellY)
    local key = tostring(page) .. ":" .. cellX .. ":" .. cellY
    local ink = inkByCell[key]
    if ink == nil then
        ink = false
        local texture = SpiffBoy.PixelFont.pageTexture(page)
        if texture then
            local left, top, right, bottom = ROBOT.cellInk(texture.file, cellX, cellY, SpiffBoy.PixelFont.CELL_WIDTH, SpiffBoy.PixelFont.CELL_HEIGHT)
            if left then
                ink = { left, top, right, bottom }
            end
        end
        inkByCell[key] = ink
    end
    return ink or nil
end

--- Returns the boxes of the pixels of the glyphs of a text drawn with its left edge at x and its top at y, placed on whole pixels as the screen draws them, and the box holding them all, or nil for a text that sets no pixel.
local function inkOf(str, x, y)
    local glyphs = SpiffBoy.PixelFont.shape(str)
    local left, top = SpiffBoy.PixelFont.origin(math.floor(x), math.floor(y))
    local pieces, bounds = {}, nil
    for i = 1, #glyphs do
        local glyph = glyphs[i]
        local ink = glyph.page and cellInk(glyph.page, glyph.cellX, glyph.cellY)
        if ink then
            local cellLeft, cellTop = left + glyph.x, top - glyph.y
            local piece = { x = cellLeft + ink[1], y = cellTop + ink[2], right = cellLeft + ink[3], bottom = cellTop + ink[4] }
            pieces[#pieces + 1] = piece
            if bounds then
                bounds.x, bounds.y = math.min(bounds.x, piece.x), math.min(bounds.y, piece.y)
                bounds.right, bounds.bottom = math.max(bounds.right, piece.right), math.max(bounds.bottom, piece.bottom)
            else
                bounds = { x = piece.x, y = piece.y, right = piece.right, bottom = piece.bottom }
            end
        end
    end
    return pieces, bounds
end

--- Returns true when two boxes share pixels.
local function meet(a, b)
    return a.x < b.right and b.x < a.right and a.y < b.bottom and b.y < a.bottom
end

--- Returns true when a box of the first list shares pixels with a box of the second.
local function anyMeet(first, second)
    for _, a in ipairs(first) do
        for _, b in ipairs(second) do
            if meet(a, b) then
                return true
            end
        end
    end
    return false
end

--- Records the pixels of the glyphs of a text drawn in the frame and warns once for each pair of places where two different texts have glyphs that share pixels of the screen.
function ROBOT.watchOverlap(str, x, y)
    local pieces, bounds = inkOf(str, x, y)
    if not bounds then
        return
    end
    for _, drawn in ipairs(ROBOT.frameTexts) do
        if drawn.str ~= str and meet(drawn.bounds, bounds) and anyMeet(drawn.pieces, pieces) then
            ROBOT.warnOnce(string.format("overlap %d,%d|%d,%d", drawn.x, drawn.y, x, y), string.format("texts overlap: %q at x %d, y %d and %q at x %d, y %d have letters on the same pixels; give each text its own room in every language (docs/06-texts-and-translations.md, Fitting the screen)", drawn.str, drawn.x, drawn.y, str, x, y))
        end
    end
    ROBOT.frameTexts[#ROBOT.frameTexts + 1] = { str = str, x = x, y = y, bounds = bounds, pieces = pieces }
end

--- Adds to a list the parts of a box that a rectangle between the given edges leaves seen: the whole box, or up to four parts of it.
local function addUncovered(into, piece, left, top, right, bottom)
    if left >= piece.right or right <= piece.x or top >= piece.bottom or bottom <= piece.y then
        into[#into + 1] = piece
        return
    end
    local high, low = math.max(piece.y, top), math.min(piece.bottom, bottom)
    if piece.y < top then
        into[#into + 1] = { x = piece.x, y = piece.y, right = piece.right, bottom = top }
    end
    if piece.bottom > bottom then
        into[#into + 1] = { x = piece.x, y = bottom, right = piece.right, bottom = piece.bottom }
    end
    if piece.x < left then
        into[#into + 1] = { x = piece.x, y = high, right = left, bottom = low }
    end
    if piece.right > right then
        into[#into + 1] = { x = right, y = high, right = piece.right, bottom = low }
    end
end

--- Cuts from the glyphs of the texts of the frame the part a filled rectangle drawn over them hides, and forgets a text hidden whole.
function ROBOT.coverTexts(x, y, width, height)
    local left, top = math.floor(x), math.floor(y)
    local right, bottom = left + math.floor(width), top + math.floor(height)
    local kept = {}
    for _, drawn in ipairs(ROBOT.frameTexts) do
        local seen = {}
        for _, piece in ipairs(drawn.pieces) do
            addUncovered(seen, piece, left, top, right, bottom)
        end
        if #seen > 0 then
            drawn.pieces = seen
            kept[#kept + 1] = drawn
        end
    end
    ROBOT.frameTexts = kept
end

--- Makes a screen record the texts it draws, warning when two different ones overlap, and forget those a filled rectangle or a clear hides; the given function receives each text with its left edge and width before it is drawn.
function ROBOT.watchTexts(screen, onText)
    screen.robotOnText = onText
end

local screenText, screenRect, screenClear = SpiffBoyScreen.text, SpiffBoyScreen.rect, SpiffBoyScreen.clear

--- Draws a text on a screen, first handing it to the screen watcher given by ROBOT.watchTexts, if any.
function SpiffBoyScreen:text(str, x, y, ...)
    if self.robotOnText then
        local width = SpiffBoy.PixelFont.measure(str)
        self.robotOnText(self, str, x, width)
        ROBOT.watchOverlap(str, x, y)
    end
    return screenText(self, str, x, y, ...)
end

--- Fills a rectangle on a screen, which hides the texts of a watched screen under it.
function SpiffBoyScreen:rect(x, y, width, height, ...)
    if self.robotOnText then
        ROBOT.coverTexts(x, y, width, height)
    end
    return screenRect(self, x, y, width, height, ...)
end

--- Clears a screen, which hides every text of a watched screen.
function SpiffBoyScreen:clear(...)
    if self.robotOnText then
        ROBOT.newFrame()
    end
    return screenClear(self, ...)
end

--- Returns the texts of the UI section of the language file of a game in the given language, by key, or nil when the file is missing or cannot be read.
function ROBOT.languageTexts(definition, language)
    local reader = getModFileReader(definition.mod, definition.texts .. language .. ".json", false)
    if not reader then
        return nil
    end
    local lines = {}
    local line = reader:readLine()
    while line do
        lines[#lines + 1] = line
        line = reader:readLine()
    end
    reader:close()
    local ok, decoded = pcall(SpiffBoy.GameTexts.decode, table.concat(lines, "\n"))
    if not ok or type(decoded) ~= "table" or type(decoded[SpiffBoy.GameTexts.SECTION]) ~= "table" then
        return nil
    end
    return decoded[SpiffBoy.GameTexts.SECTION]
end

--- Returns the keys of a table as a sorted list.
local function sortedKeys(entries)
    local keys = {}
    for key, _ in pairs(entries) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

--- Measures every text of the language played in the language file of a game, so the pixel font reports a character it lacks even in a text of a screen never opened.
function ROBOT.measureTexts(definition)
    local texts = ROBOT.languageTexts(definition, ROBOT.language)
    if not texts then
        return
    end
    for _, key in ipairs(sortedKeys(texts)) do
        if type(texts[key]) == "string" then
            SpiffBoy.PixelFont.measure(texts[key])
        end
    end
end

--- Forgets the tunes played, the texts asked for and the noted warning, before a game is played.
function ROBOT.beginCoverage()
    ROBOT.playedTunes, ROBOT.askedTexts, ROBOT.notedWarning = {}, {}, nil
end

--- Returns the names of the tunes a game registered that it never played, and the keys of its English texts it never asked for, each as a text listing them sorted, empty when there is none.
function ROBOT.coverage(definition)
    local unplayed, unasked = {}, {}
    local set = SpiffBoy.Tunes.set(definition.id)
    if set then
        for _, name in ipairs(sortedKeys(set.tunes)) do
            if not ROBOT.playedTunes[name] then
                unplayed[#unplayed + 1] = tostring(name)
            end
        end
    end
    local english = ROBOT.languageTexts(definition, SpiffBoy.GameTexts.REFERENCE_LANGUAGE)
    if english then
        for _, key in ipairs(sortedKeys(english)) do
            if not ROBOT.askedTexts[key] then
                unasked[#unasked + 1] = tostring(key)
            end
        end
    end
    return table.concat(unplayed, ", "), table.concat(unasked, ", ")
end

local findTune = SpiffBoySequencer.tune

--- Returns the compiled tune of the given name, as the console does, and records that the game played it.
function SpiffBoySequencer:tune(name)
    local tune = findTune(self, name)
    ROBOT.playedTunes[name] = true
    return tune
end

local gameText = SpiffBoy.GameTexts.text

--- Returns the text of a key of a game, as the console does, and records that the game asked for it.
SpiffBoy.GameTexts.text = function(definition, key, ...)
    ROBOT.askedTexts[key] = true
    return gameText(definition, key, ...)
end

--- Returns the names of the global variables, as a set.
function ROBOT.globalNames()
    local names = {}
    for name, _ in pairs(_G) do
        names[name] = true
    end
    return names
end
