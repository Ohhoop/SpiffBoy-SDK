require "SpiffBoySDK/DevMenu/DevMenuItems"

local Items = SpiffBoySDK.DevMenuItems

--- Gives the items a client asks for through the menu and sends back how many arrived; a player whose role may not add items or a request that does not validate gets nothing.
local function onClientCommand(module, command, player, args)
    if module ~= Items.COMMAND_MODULE or command ~= Items.COMMAND_GIVE or not player then
        return
    end
    if not Items.mayGive(player) then
        print("SpiffBoySDK: give refused for " .. tostring(player:getUsername()))
        return
    end
    local request = Items.clean(args)
    if not request then
        print("SpiffBoySDK: invalid give request from " .. tostring(player:getUsername()))
        return
    end
    local added, skipped = Items.give(player, request)
    request.added = added
    request.skipped = skipped
    sendServerCommand(player, Items.COMMAND_MODULE, Items.COMMAND_GIVEN, request)
end

Events.OnClientCommand.Add(onClientCommand)
