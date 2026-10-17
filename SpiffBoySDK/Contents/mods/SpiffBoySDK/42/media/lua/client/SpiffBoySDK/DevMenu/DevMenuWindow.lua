require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "SpiffBoy/Framework/Cartridges"
require "SpiffBoySDK/DevMenu/DevMenuItems"
require "SpiffBoySDK/DevMenu/DevMenuActions"

SpiffBoySDK.DevMenuWindow = SpiffBoySDK.DevMenuWindow or {}
local Window = SpiffBoySDK.DevMenuWindow
local Items = SpiffBoySDK.DevMenuItems
local Actions = SpiffBoySDK.DevMenuActions

SpiffBoySDKDevMenuList = ISPanel:derive("SpiffBoySDKDevMenuList")
SpiffBoySDKDevMenuPanel = ISCollapsableWindow:derive("SpiffBoySDKDevMenuPanel")

local MIN_CARTRIDGE_WIDTH = 200
local MAX_SCREEN_SHARE = 0.7
local SCROLLBAR_WIDTH = 13
local HEADER_COLOUR = { r = 0.6, g = 0.8, b = 0.95 }

local window = nil
local lastX = nil
local lastY = nil

--- Returns the text of the button giving the cartridge: its title and the id of its mod.
local function cartridgeLabel(definition)
    return getText("UI_SpiffBoySDK_CartridgeLabel", definition.title, definition.mod)
end

--- Computes the font, spacing, column widths and content height of the menu for the given cartridge definitions.
local function computeLayout(definitions)
    local textManager = getTextManager()
    local font = UIFont.Small
    local fontHeight = textManager:getFontHeight(font)
    local padding = math.ceil(fontHeight * 0.3)
    local buttonHeight = fontHeight + padding * 2
    local step = buttonHeight + padding
    local widest = MIN_CARTRIDGE_WIDTH
    for _, device in ipairs(Items.DEVICES) do
        widest = math.max(widest, textManager:MeasureStringX(font, getText(device.text)) + padding * 4)
    end
    for i = 1, #definitions do
        widest = math.max(widest, textManager:MeasureStringX(font, cartridgeLabel(definitions[i])) + padding * 4)
    end
    local loadedWidth = textManager:MeasureStringX(font, getText("UI_SpiffBoySDK_InConsole")) + padding * 4
    local rows = math.max(#definitions, 1)
    local contentHeight = padding + (fontHeight + padding) * 2 + #Items.DEVICES * step + rows * step + padding
    if #definitions > 0 then
        contentHeight = contentHeight + step
    end
    return {
        font = font,
        fontHeight = fontHeight,
        padding = padding,
        buttonHeight = buttonHeight,
        step = step,
        cartridgeWidth = widest,
        loadedWidth = loadedWidth,
        fullWidth = widest + padding + loadedWidth,
        listWidth = padding * 3 + widest + loadedWidth + padding + SCROLLBAR_WIDTH,
        contentHeight = contentHeight,
    }
end

--- Creates the scrolling list of buttons with the given layout and cartridge definitions.
function SpiffBoySDKDevMenuList:new(x, y, width, height, layout, definitions)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    o.layout = layout
    o.definitions = definitions
    return o
end

--- Asks for the items of the request attached to the pressed button.
function SpiffBoySDKDevMenuList:onPress(button, request)
    Actions.request(request)
end

--- Adds a section title at the given height and returns the height below it.
function SpiffBoySDKDevMenuList:addHeader(text, y)
    local layout = self.layout
    local label = ISLabel:new(layout.padding, y, layout.fontHeight, text, HEADER_COLOUR.r, HEADER_COLOUR.g, HEADER_COLOUR.b, 1, layout.font, true)
    label:initialise()
    label:instantiate()
    self:addChild(label)
    return y + layout.fontHeight + layout.padding
end

--- Adds a button asking for the request at the given place.
function SpiffBoySDKDevMenuList:addButton(x, y, width, text, request)
    local button = ISButton:new(x, y, width, self.layout.buttonHeight, text, self)
    button:setOnClick(SpiffBoySDKDevMenuList.onPress, request)
    button:initialise()
    button:instantiate()
    self:addChild(button)
end

--- Adds the device buttons, one row per registered cartridge with its console button, and the all cartridges button.
function SpiffBoySDKDevMenuList:createChildren()
    ISPanel.createChildren(self)
    self:addScrollBars()
    self:setScrollChildren(true)
    local layout = self.layout
    local left = layout.padding
    local y = self:addHeader(getText("UI_SpiffBoySDK_Devices"), layout.padding)
    for _, device in ipairs(Items.DEVICES) do
        self:addButton(left, y, layout.fullWidth, getText(device.text), { kind = Items.KIND_DEVICE, id = device.id })
        y = y + layout.step
    end
    y = self:addHeader(getText("UI_SpiffBoySDK_Cartridges"), y)
    local definitions = self.definitions
    if #definitions == 0 then
        y = self:addHeader(getText("UI_SpiffBoySDK_NoCartridges"), y)
    end
    for i = 1, #definitions do
        local definition = definitions[i]
        self:addButton(left, y, layout.cartridgeWidth, cartridgeLabel(definition), { kind = Items.KIND_CARTRIDGE, item = definition.item })
        self:addButton(left + layout.cartridgeWidth + layout.padding, y, layout.loadedWidth, getText("UI_SpiffBoySDK_InConsole"), { kind = Items.KIND_LOADED, item = definition.item })
        y = y + layout.step
    end
    if #definitions > 0 then
        self:addButton(left, y, layout.fullWidth, getText("UI_SpiffBoySDK_AllCartridges"), { kind = Items.KIND_ALL })
        y = y + layout.step
    end
    self:setScrollHeight(y + layout.padding)
end

--- Clips the drawing of the list to its area.
function SpiffBoySDKDevMenuList:prerender()
    ISPanel.prerender(self)
    self:setStencilRect(0, 0, self.width, self.height)
end

--- Ends the clipping of the list.
function SpiffBoySDKDevMenuList:render()
    ISPanel.render(self)
    self:clearStencilRect()
end

--- Scrolls the list by one row per wheel step, kept within its content.
function SpiffBoySDKDevMenuList:onMouseWheel(del)
    local lowest = math.min(0, self.height - self:getScrollHeight())
    self:setYScroll(math.max(lowest, math.min(0, self:getYScroll() - del * self.layout.step)))
    return true
end

--- Creates the window at the given place with the given size, layout and cartridge definitions.
function SpiffBoySDKDevMenuPanel:new(x, y, width, height, layout, definitions)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.title = getText("UI_SpiffBoySDK_Title")
    o.resizable = false
    o.layout = layout
    o.definitions = definitions
    return o
end

--- Adds the scrolling list under the title bar.
function SpiffBoySDKDevMenuPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight()
    self.list = SpiffBoySDKDevMenuList:new(0, top, self.width, self.height - top, self.layout, self.definitions)
    self.list:initialise()
    self.list:instantiate()
    self:addChild(self.list)
end

--- Remembers where the window stood and removes it from the interface.
function SpiffBoySDKDevMenuPanel:close()
    Window.close()
end

--- Closes the window when it is open, remembering where it stood.
function Window.close()
    if not window then
        return
    end
    lastX = window:getX()
    lastY = window:getY()
    window:setVisible(false)
    window:removeFromUIManager()
    window = nil
end

--- Opens the window with one row per cartridge registered now, by any mod, at its last place or in the middle of the screen.
function Window.open()
    Window.close()
    local definitions = SpiffBoy.Cartridges.all()
    local layout = computeLayout(definitions)
    local core = getCore()
    local screenWidth = core:getScreenWidth()
    local screenHeight = core:getScreenHeight()
    local titleHeight = math.max(16, getTextManager():getFontHeight(UIFont.Small) + 1)
    local width = layout.listWidth
    local height = titleHeight + math.min(layout.contentHeight, math.floor(screenHeight * MAX_SCREEN_SHARE))
    local x = lastX or math.floor((screenWidth - width) / 2)
    local y = lastY or math.floor((screenHeight - height) / 2)
    x = math.max(0, math.min(x, screenWidth - width))
    y = math.max(0, math.min(y, screenHeight - height))
    window = SpiffBoySDKDevMenuPanel:new(x, y, width, height, layout, definitions)
    window:initialise()
    window:instantiate()
    window:addToUIManager()
    window:bringToTop()
end

Events.OnPlayerDeath.Add(Window.close)
Events.OnMainMenuEnter.Add(Window.close)
