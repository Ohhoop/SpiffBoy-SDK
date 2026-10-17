local failures = 0
local checks = 0

--- Counts one check and prints the failed ones.
local function check(condition, message)
    checks = checks + 1
    if not condition then
        failures = failures + 1
        print("FAIL " .. message)
    end
end

local mode = { client = false, server = false }
function isClient() return mode.client end
function isServer() return mode.server end

Capability = { AddItem = "AddItem" }

luautils = {}
function luautils.stringEnds(text, ending)
    return string.sub(text, -string.len(ending)) == ending
end

local handlers = {}
Events = setmetatable({}, {
    __index = function(t, name)
        local event = { Add = function(fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end }
        rawset(t, name, event)
        return event
    end,
})

--- Runs every handler registered on the event with the given arguments.
local function fire(name, ...)
    for _, fn in ipairs(handlers[name] or {}) do
        fn(...)
    end
end

local knownTypes = {
    ["Base.VideoGame"] = true, ["Base.Battery"] = true, ["Base.Headphones"] = true,
    ["Base.Earbuds"] = true, ["SpiffBoy.LinkCable"] = true,
}

--- Creates an item stub of the given type.
local function makeItem(fullType)
    local item = { fullType = fullType, modData = {}, weight = 0.5, custom = false }
    function item:getFullType() return self.fullType end
    function item:getModData() return self.modData end
    function item:getActualWeight() return self.weight end
    function item:setActualWeight(w) self.weight = w end
    function item:isCustomWeight() return self.custom end
    function item:setCustomWeight(c) self.custom = c end
    function item:setUsedDelta(d) self.delta = d end
    return item
end

function instanceItem(fullType)
    if not knownTypes[fullType] then
        return nil
    end
    return makeItem(fullType)
end

function getScriptManager()
    return { FindItem = function(_, t) return { getActualWeight = function() return 0.5 end } end }
end

local serverSent = {}
local clientSent = {}
local syncedItems = 0
function sendServerCommand(player, module, command, args) table.insert(serverSent, { player = player, module = module, command = command, args = args }) end
function sendClientCommand(player, module, command, args) table.insert(clientSent, { player = player, module = module, command = command, args = args }) end
function sendAddItemToContainer(inventory, item) syncedItems = syncedItems + 1 end

--- Creates a player stub holding the given capabilities and room for the given number of items.
local function makePlayer(name, capabilities, room)
    local inventory = { items = {}, room = room }
    function inventory:hasRoomFor(player, item) return #self.items < self.room end
    function inventory:AddItem(item) table.insert(self.items, item) end
    local role = { caps = capabilities }
    function role:hasCapability(cap) return self.caps[cap] == true end
    local player = { inventory = inventory, role = role, name = name }
    function player:getInventory() return self.inventory end
    function player:getRole() return self.role end
    function player:getUsername() return self.name end
    function player:isDead() return false end
    return player
end

local localPlayer = nil
function getPlayer() return localPlayer end
function getText(key, ...)
    local parts = { key }
    for _, v in ipairs({ ... }) do parts[#parts + 1] = tostring(v) end
    return table.concat(parts, "|")
end
local halos = {}
HaloTextHelper = {
    addText = function(player, text, sep, colour) table.insert(halos, { text = text, colour = colour }) end,
    getColorGreen = function() return "green" end,
    getColorRed = function() return "red" end,
}

local loaded = {}
function require(name)
    if loaded[name] then
        return
    end
    loaded[name] = true
    if name == "luautils" then
        return
    end
    local source = read_module(name)
    if not source then
        error("module not found: " .. name)
    end
    local chunk, err = loadstring(source, "@" .. name)
    if not chunk then
        error(err)
    end
    chunk()
end

require "SpiffBoy/Core/Core"
require "SpiffBoy/Core/Commands"
require "SpiffBoy/Framework/Cartridges"
require "SpiffBoySDK/DevMenu/DevMenuItems"
require "SpiffBoySDK/DevMenu/DevMenuCommands"
require "SpiffBoySDK/DevMenu/DevMenuActions"

local Items = SpiffBoySDK.DevMenuItems
local Cartridges = SpiffBoy.Cartridges

--- Registers a cartridge of the given mod and makes its item type creatable.
local function registerCartridge(id, item, title, mod)
    knownTypes[item] = true
    Cartridges.register({ api = 1, id = id, item = item, title = title, game = id .. "Game", mod = mod, art = "media/ui/" .. id .. "/", texts = "media/lua/shared/" .. id .. "/Translate/" })
end

registerCartridge("BrickDrop", "SpiffBoy.BrickDropCartridge", "Brick Drop", "SpiffBoy")
registerCartridge("HelloSpiffBoy", "SpiffBoySDK.HelloSpiffBoyCartridge", "Hello SpiffBoy", "SpiffBoySDK")
registerCartridge("ModderGame", "ModderMod.ModderCartridge", "Modder Game", "ModderMod")

local function countType(player, fullType)
    local n = 0
    for _, item in ipairs(player:getInventory().items) do
        if item:getFullType() == fullType then n = n + 1 end
    end
    return n
end

check(Items.clean({ kind = "device", id = "console" }) ~= nil, "known device accepted")
check(Items.clean({ kind = "device", id = "Base.Axe" }) == nil, "unknown device refused")
check(Items.clean({ kind = "device", id = 3 }) == nil, "numeric device id refused")
check(Items.clean({ kind = "device" }) == nil, "missing device id refused")
check(Items.clean({ kind = "cartridge", item = "ModderMod.ModderCartridge" }) ~= nil, "cartridge of another mod accepted")
check(Items.clean({ kind = "cartridge", item = "Base.Axe" }) == nil, "item type that is not a cartridge refused")
check(Items.clean({ kind = "loaded", item = "Base.VideoGame" }) == nil, "console as loaded cartridge refused")
check(Items.clean({ kind = "cartridge", item = { "x" } }) == nil, "table item refused")
check(Items.clean({ kind = "spawn", item = "Base.Axe" }) == nil, "unknown kind refused")
check(Items.clean("all") == nil, "non table request refused")
local stripped = Items.clean({ kind = "all", item = "Base.Axe", count = 99 })
check(stripped and stripped.item == nil and stripped.count == nil, "extra fields stripped")

local solo = makePlayer("solo", {}, 100)
localPlayer = solo
for _, device in ipairs(Items.DEVICES) do
    local added, skipped = Items.give(solo, { kind = "device", id = device.id })
    check(added == 1 and skipped == 0, "solo device " .. device.id .. " given")
    check(countType(solo, device.item) >= 1, "solo device " .. device.id .. " in inventory")
end

local added = Items.give(solo, { kind = "all" })
check(added == #Cartridges.all() and added == 3, "all cartridges follows Cartridges.all")
for _, definition in ipairs(Cartridges.all()) do
    check(countType(solo, definition.item) == 1, "all cartridges gave " .. definition.item)
end

registerCartridge("LateGame", "LateMod.LateCartridge", "Late Game", "LateMod")
added = Items.give(solo, { kind = "all" })
check(added == 4 and countType(solo, "LateMod.LateCartridge") == 1, "cartridge registered later is listed")
check(Items.clean({ kind = "cartridge", item = "LateMod.LateCartridge" }) ~= nil, "later cartridge accepted")

local before = #solo:getInventory().items
added = Items.give(solo, { kind = "loaded", item = "ModderMod.ModderCartridge" })
local console = solo:getInventory().items[before + 1]
check(added == 1 and console:getFullType() == "Base.VideoGame", "loaded console given")
local record = console:getModData().SpiffBoy and console:getModData().SpiffBoy.cartridge
check(record and record.type == "ModderMod.ModderCartridge", "loaded console holds the cartridge")
check(syncedItems == 0, "solo does not sync items")

halos = {}
local Actions = SpiffBoySDK.DevMenuActions
Actions.request({ kind = "cartridge", item = "SpiffBoy.BrickDropCartridge" })
check(#halos == 1 and halos[1].colour == "green", "solo request shows the added halo")
check(#clientSent == 0, "solo request sends no command")

mode.server = true
serverSent = {}
local refused = makePlayer("guest", {}, 100)
fire("OnClientCommand", "SpiffBoySDK", "give", refused, { kind = "all" })
fire("OnClientCommand", "SpiffBoySDK", "give", refused, { kind = "device", id = "console" })
check(#refused:getInventory().items == 0, "player without capability gets nothing")
check(#serverSent == 0, "player without capability gets no reply")
check(Items.give(refused, { kind = "all" }) == nil, "give refuses a player without capability")

local admin = makePlayer("admin", { AddItem = true }, 100)
fire("OnClientCommand", "SpiffBoySDK", "give", admin, { kind = "device", id = "Base.Axe" })
fire("OnClientCommand", "SpiffBoySDK", "give", admin, { kind = "cartridge", item = "Base.Axe" })
fire("OnClientCommand", "SpiffBoySDK", "give", admin, { kind = "loaded", item = "Base.Battery" })
fire("OnClientCommand", "SpiffBoySDK", "give", admin, "console")
fire("OnClientCommand", "SpiffBoySDK", "give", admin, nil)
fire("OnClientCommand", "SpiffBoySDK", "spawn", admin, { kind = "all" })
fire("OnClientCommand", "SpiffBoy", "give", admin, { kind = "all" })
check(#admin:getInventory().items == 0, "invalid requests give nothing")
check(#serverSent == 0, "invalid requests get no reply")

syncedItems = 0
fire("OnClientCommand", "SpiffBoySDK", "give", admin, { kind = "cartridge", item = "SpiffBoySDK.HelloSpiffBoyCartridge" })
check(countType(admin, "SpiffBoySDK.HelloSpiffBoyCartridge") == 1, "server gives a cartridge to a player with capability")
check(syncedItems == 1, "server syncs the added item")
check(#serverSent == 1 and serverSent[1].command == "given" and serverSent[1].args.added == 1 and serverSent[1].args.skipped == 0, "server replies with the counts")

serverSent = {}
fire("OnClientCommand", "SpiffBoySDK", "give", admin, { kind = "all" })
check(#admin:getInventory().items == 5 and serverSent[1].args.added == 4, "server gives every cartridge")

local full = makePlayer("full", { AddItem = true }, 2)
serverSent = {}
fire("OnClientCommand", "SpiffBoySDK", "give", full, { kind = "all" })
check(#full:getInventory().items == 2 and serverSent[1].args.added == 2 and serverSent[1].args.skipped == 2, "items without room are counted as skipped")
mode.server = false

mode.client = true
clientSent = {}
localPlayer = admin
Actions.request({ kind = "device", id = "cable" })
check(#clientSent == 1 and clientSent[1].module == "SpiffBoySDK" and clientSent[1].command == "give", "client request goes to the server")
check(Items.mayGive(admin) and not Items.mayGive(refused), "client gating follows the role")
halos = {}
fire("OnServerCommand", "SpiffBoySDK", "given", { kind = "device", id = "cable", added = 1, skipped = 1 })
check(#halos == 2, "client shows the server reply")
halos = {}
fire("OnServerCommand", "SpiffBoySDK", "given", { kind = "device", id = "nope", added = 1, skipped = 0 })
fire("OnServerCommand", "SpiffBoySDK", "given", { kind = "device", id = "cable", added = "x", skipped = 0 })
fire("OnServerCommand", "SpiffBoy", "given", { kind = "device", id = "cable", added = 1, skipped = 0 })
check(#halos == 0, "client ignores malformed replies")
mode.client = false

for _, name in ipairs({ "SpiffBoySDK/DevMenu/DevMenuWindow", "SpiffBoySDK/DevMenu/DevMenuEntry" }) do
    local chunk, err = loadstring(read_module(name), "@" .. name)
    check(chunk ~= nil, "compiles " .. name .. " " .. tostring(err))
end

print(string.format("dev menu: %d checks, %d failures", checks, failures))
return failures
