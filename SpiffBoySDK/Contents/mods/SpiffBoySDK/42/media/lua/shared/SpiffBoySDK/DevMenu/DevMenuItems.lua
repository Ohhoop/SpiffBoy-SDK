require "SpiffBoy/Core/Core"
require "SpiffBoy/Framework/Cartridges"
require "SpiffBoy/Handheld/Handheld"
require "SpiffBoySDK/Core"

SpiffBoySDK.DevMenuItems = SpiffBoySDK.DevMenuItems or {}
local Items = SpiffBoySDK.DevMenuItems

Items.COMMAND_MODULE = "SpiffBoySDK"
Items.COMMAND_GIVE = "give"
Items.COMMAND_GIVEN = "given"
Items.KIND_DEVICE = "device"
Items.KIND_CARTRIDGE = "cartridge"
Items.KIND_LOADED = "loaded"
Items.KIND_ALL = "all"
Items.DEVICES = {
    { id = "console", item = SpiffBoy.CONSOLE_ITEM, text = "UI_SpiffBoySDK_Console" },
    { id = "battery", item = SpiffBoy.BATTERY_ITEM, text = "UI_SpiffBoySDK_Battery" },
    { id = "headphones", item = "Base.Headphones", text = "UI_SpiffBoySDK_Headphones" },
    { id = "earbuds", item = "Base.Earbuds", text = "UI_SpiffBoySDK_Earbuds" },
    { id = "cable", item = SpiffBoy.CABLE_ITEM, text = "UI_SpiffBoySDK_LinkCable" },
}

local devicesById = {}
for _, device in ipairs(Items.DEVICES) do
    devicesById[device.id] = device
end

--- Returns the device of the menu with the given id, or nil.
function Items.device(id)
    if type(id) ~= "string" then
        return nil
    end
    return devicesById[id]
end

--- Returns the cartridge definition registered for the given item type, or nil.
function Items.cartridge(itemType)
    if type(itemType) ~= "string" then
        return nil
    end
    return SpiffBoy.Cartridges.get(itemType)
end

--- Returns a new request holding only the fields of its kind, or nil when the kind is unknown, the device id is not a device of the menu or the item type is not a registered cartridge.
function Items.clean(request)
    if type(request) ~= "table" then
        return nil
    end
    local kind = request.kind
    if kind == Items.KIND_DEVICE then
        if not Items.device(request.id) then
            return nil
        end
        return { kind = kind, id = request.id }
    end
    if kind == Items.KIND_CARTRIDGE or kind == Items.KIND_LOADED then
        if not Items.cartridge(request.item) then
            return nil
        end
        return { kind = kind, item = request.item }
    end
    if kind == Items.KIND_ALL then
        return { kind = kind }
    end
    return nil
end

--- Returns true when the player may receive items from the menu: always in solo, only with a role that may add items in multiplayer.
function Items.mayGive(player)
    if not isClient() and not isServer() then
        return true
    end
    return player:getRole():hasCapability(Capability.AddItem)
end

--- Returns a new item of the given type, or nil with a line in the log when the game cannot create it.
local function newItem(itemType)
    local item = instanceItem(itemType)
    if not item then
        print("SpiffBoySDK: cannot create " .. tostring(itemType))
    end
    return item
end

--- Returns a new console holding a fresh cartridge of the given item type, or nil when the game cannot create the console.
local function loadedConsole(itemType)
    local console = newItem(SpiffBoy.CONSOLE_ITEM)
    if console then
        SpiffBoy.Handheld.setCartridge(console, SpiffBoy.Handheld.newRecord(itemType, {}))
    end
    return console
end

--- Returns the new items a clean request asks for, leaving out those the game cannot create.
local function createItems(request)
    local items = {}
    local kind = request.kind
    if kind == Items.KIND_DEVICE then
        items[#items + 1] = newItem(Items.device(request.id).item)
    elseif kind == Items.KIND_CARTRIDGE then
        items[#items + 1] = newItem(request.item)
    elseif kind == Items.KIND_LOADED then
        items[#items + 1] = loadedConsole(request.item)
    elseif kind == Items.KIND_ALL then
        local definitions = SpiffBoy.Cartridges.all()
        for i = 1, #definitions do
            items[#items + 1] = newItem(definitions[i].item)
        end
    end
    return items
end

--- Puts the items the request asks for in the main inventory of the player when they fit, and returns how many were added and how many found no room, or nil when the player may not receive them or the request is invalid.
function Items.give(player, request)
    if not player or not Items.mayGive(player) then
        return nil
    end
    local clean = Items.clean(request)
    if not clean then
        return nil
    end
    local inventory = player:getInventory()
    local added, skipped = 0, 0
    for _, item in ipairs(createItems(clean)) do
        if inventory:hasRoomFor(player, item) then
            inventory:AddItem(item)
            if isServer() then
                sendAddItemToContainer(inventory, item)
            end
            added = added + 1
        else
            skipped = skipped + 1
        end
    end
    return added, skipped
end
