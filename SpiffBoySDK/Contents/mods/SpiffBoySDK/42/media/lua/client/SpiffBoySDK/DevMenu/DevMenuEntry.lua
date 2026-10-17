require "SpiffBoySDK/DevMenu/DevMenuItems"
require "SpiffBoySDK/DevMenu/DevMenuWindow"

local Items = SpiffBoySDK.DevMenuItems
local Window = SpiffBoySDK.DevMenuWindow

--- Adds the entry opening the menu to the world right click menu of a living player who may receive its items.
local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test and ISWorldObjectContextMenu.Test then
        return true
    end
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() or not Items.mayGive(player) then
        return
    end
    context:addOption(getText("UI_SpiffBoySDK_Title"), nil, Window.open)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
