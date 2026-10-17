require "SpiffBoy/Core/Commands"
require "SpiffBoySDK/DevMenu/DevMenuItems"

SpiffBoySDK.DevMenuActions = SpiffBoySDK.DevMenuActions or {}
local Actions = SpiffBoySDK.DevMenuActions
local Items = SpiffBoySDK.DevMenuItems

--- Returns the text naming what a clean request gives: the device, the cartridge title, the console with the cartridge title, or every cartridge.
function Actions.label(request)
    local kind = request.kind
    if kind == Items.KIND_DEVICE then
        return getText(Items.device(request.id).text)
    end
    if kind == Items.KIND_ALL then
        return getText("UI_SpiffBoySDK_AllCartridges")
    end
    local title = Items.cartridge(request.item).title
    if kind == Items.KIND_LOADED then
        return getText("UI_SpiffBoySDK_ConsoleWith", title)
    end
    return title
end

--- Shows above the player how many items of a clean request arrived and how many found no room.
function Actions.report(player, request, added, skipped)
    if added > 0 then
        HaloTextHelper.addText(player, getText("UI_SpiffBoySDK_Added", tostring(added), Actions.label(request)), "", HaloTextHelper.getColorGreen())
    end
    if skipped > 0 then
        HaloTextHelper.addText(player, getText("UI_SpiffBoySDK_NoRoom", tostring(skipped)), "", HaloTextHelper.getColorRed())
    end
end

--- Asks for the items of the request for the local player: through the server in multiplayer, directly in solo.
function Actions.request(request)
    local player = getPlayer()
    if not player or player:isDead() then
        return
    end
    if isClient() then
        sendClientCommand(player, Items.COMMAND_MODULE, Items.COMMAND_GIVE, request)
        return
    end
    local added, skipped = Items.give(player, request)
    if added then
        Actions.report(player, Items.clean(request), added, skipped)
    end
end

--- Shows the result of a request the server handled.
local function onServerCommand(module, command, args)
    if module ~= Items.COMMAND_MODULE or command ~= Items.COMMAND_GIVEN then
        return
    end
    local request = Items.clean(args)
    local player = getPlayer()
    if not request or not player or not SpiffBoy.isInteger(args.added) or not SpiffBoy.isInteger(args.skipped) then
        return
    end
    Actions.report(player, request, args.added, args.skipped)
end

Events.OnServerCommand.Add(onServerCommand)
