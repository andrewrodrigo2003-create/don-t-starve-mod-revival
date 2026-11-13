-- Focused UI contract harness for the forge's visual forecast.
-- Run from the repository root with Lua 5.1:
--   lua5.1 dst-mods/tests/forge_visual_preview_test.lua
-- This verifies widget lifecycle and data presentation with narrow UI stubs;
-- it does not replace a real DST UI/runtime test.

local current_plan = {
    phase = "ready",
    state = "ready",
    product = "copper_ingot",
    count = 3,
    ambiguous = false,
}

local forecast = {
    plan = function() return current_plan end,
    product_name = function(prefab)
        local names = {
            copper_ingot = "Copper Ingot",
            iron_ingot = "Iron Ingot",
        }
        return names[prefab] or prefab
    end,
    button_text = function() return "Makes 3 Copper Ingot" end,
}
local log = {
    Try = function(_, fn, ...)
        local ok, result = pcall(fn, ...)
        return ok, result
    end,
}

local function make_node(name)
    local node = {
        name = name,
        children = {},
        visible = true,
        killed = false,
    }
    function node:AddChild(child)
        table.insert(self.children, child)
        child.parent = self
        return child
    end
    function node:SetPosition(...)
        local values = { ... }
        -- DST widgets receive either Vector3(x, y, z) or numeric coordinates.
        -- Preserve a Vector3 as the position object instead of wrapping it in
        -- a second table; this mirrors the engine API used by the forge panel.
        if #values == 1 and type(values[1]) == "table" and values[1].x ~= nil then
            self.position = values[1]
        else
            self.position = values
        end
    end
    function node:SetSize(value) self.size = value end
    function node:SetScale(value) self.scale = value end
    function node:SetColour(...) self.colour = { ... } end
    function node:SetString(value) self.string = value end
    function node:SetHAlign(value) self.halign = value end
    function node:SetVAlign(value) self.valign = value end
    function node:SetRegionSize(w, h) self.region = { w, h } end
    function node:EnableWordWrap(value) self.word_wrap = value end
    function node:SetTexture(atlas, texture)
        self.atlas = atlas
        self.texture = texture
    end
    function node:Show() self.visible = true end
    function node:Hide() self.visible = false end
    function node:Kill() self.killed = true end
    return node
end

local GLOBAL = {
    require = require,
    Vector3 = function(x, y, z) return { x = x, y = y, z = z } end,
    GetInventoryItemAtlas = function(image) return "images/inventoryimages.xml" end,
    BODYTEXTFONT = "body",
    UIFONT = "ui",
    NUMBERFONT = "number",
    ANCHOR_LEFT = "left",
    ANCHOR_MIDDLE = "middle",
}
_G.GLOBAL = GLOBAL

package.preload["mam/log"] = function() return log end
package.preload["mam/forecast"] = function() return forecast end
package.preload["widgets/widget"] = function()
    return function(name) return make_node(name) end
end
package.preload["widgets/image"] = function()
    return function(atlas, texture)
        local image = make_node("Image")
        if atlas ~= nil then
            image:SetTexture(atlas, texture)
        end
        return image
    end
end
package.preload["widgets/text"] = function()
    return function(font, size, value)
        local text = make_node("Text")
        text.font = font
        text.size = size
        text.string = value
        return text
    end
end

local class_post_init
function AddClassPostConstruct(name, fn)
    assert(name == "widgets/containerwidget")
    class_post_init = fn
end

local ContainerWidget = {}
ContainerWidget.__index = ContainerWidget
function ContainerWidget:SetScale(value) self.scale = value end
function ContainerWidget:AddChild(child)
    self.children = self.children or {}
    table.insert(self.children, child)
    child.parent = self
    return child
end
function ContainerWidget:Open(container, doer, extra)
    self.container = container
    self.button = {
        text = "",
        SetText = function(button, value) button.text = value end,
    }
    self.isopen = true
    return "opened", nil, extra
end
function ContainerWidget:Close()
    self.container = nil
    self.isopen = false
    return "closed"
end
function ContainerWidget:Refresh()
    self.refreshes = (self.refreshes or 0) + 1
    return "refreshed", nil, "refresh-tail"
end
function ContainerWidget:OnItemGet()
    self.itemgets = (self.itemgets or 0) + 1
    return "got-item", nil, "itemget-tail"
end
function ContainerWidget:OnItemLose()
    self.itemloses = (self.itemloses or 0) + 1
    return "lost-item", nil, "itemlose-tail"
end

local source = "dst-mods/metals_and_reforged/initialise/modded_ui_forecast.lua"
dofile(source)
assert(type(class_post_init) == "function", "container widget post-init was not registered")
class_post_init(ContainerWidget)

local function make_container(prefab)
    local container = {
        prefab = prefab,
        listeners = {},
        replica = {
            container = {
                GetWidget = function()
                    return { buttoninfo = { textfn = forecast.button_text } }
                end,
            },
        },
    }
    function container:ListenForEvent(event, fn) self.listeners[event] = fn end
    function container:RemoveEventCallback(event, fn)
        if self.listeners[event] == fn then self.listeners[event] = nil end
    end
    function container:IsValid() return true end
    return container
end

local function find_child(parent, name)
    for _, child in ipairs(parent.children or {}) do
        if child.name == name then return child end
    end
end

local widget = setmetatable({ children = {} }, ContainerWidget)
local forge = make_container("metal_smelter")
local open_result, open_middle, open_tail = widget:Open(forge, "doer", "open-tail")
assert(open_result == "opened" and open_middle == nil and open_tail == "open-tail",
    "Open must preserve all base return values and forward extra arguments")
assert(widget.mam_forge_preview ~= nil, "forge preview panel must be created")
assert(widget.mam_forge_preview.position.x == -270,
    "forge preview must move clear of the input slots")
assert(widget.scale == 1.2,
    "forge container HUD and its preview must be enlarged by 20%")
assert(widget.mam_forge_preview.name.string == "Copper Ingot", "product name must be displayed")
assert(widget.mam_forge_preview.name.position[1] == -48
    and widget.mam_forge_preview.name.position[2] == 54,
    "product name must overlay the top of the product image")
assert(widget.mam_forge_preview.quantity.string == "3",
    "predicted quantity must use the compact vanilla stack label")
assert(widget.mam_forge_preview.quantity.font == "number",
    "quantity must use the vanilla number font")
assert(widget.mam_forge_preview.quantity.size == 42,
    "quantity must use the vanilla stack number size")
assert(widget.mam_forge_preview.quantity.position[1] > -48
    and widget.mam_forge_preview.quantity.position[2] < 22,
    "quantity must sit inside the lower-right area of the product image")
assert(widget.mam_forge_preview.icon.texture == "copper_ingot.tex", "real product texture must be selected")
assert(widget.mam_forge_preview.icon.atlas == "images/inventoryimages/copper_ingot.xml",
    "custom MAM product must use its dedicated inventory atlas")
assert(widget.mam_forge_preview.icon.visible, "product image must be visible")
assert(widget.mam_forge_preview.details.string == "Predicted output", "forecast state must be displayed")

current_plan = {
    phase = "ready",
    state = "ready",
    product = "iron_ingot",
    count = 2,
}
local get_result, get_middle, get_tail = widget:OnItemGet({})
assert(get_result == "got-item" and get_middle == nil and get_tail == "itemget-tail",
    "OnItemGet must preserve all base return values")
assert(widget.mam_forge_preview.name.string == "Iron Ingot", "item changes must refresh product name")
assert(widget.mam_forge_preview.quantity.string == "2", "item changes must refresh the stack count")
assert(widget.mam_forge_preview.icon.texture == "iron_ingot.tex", "item changes must refresh product image")

current_plan = {
    phase = "ready",
    state = "ready",
    product = "copper_ingot",
    count = 1500,
}
local refresh_result, refresh_middle, refresh_tail = widget:Refresh()
assert(refresh_result == "refreshed" and refresh_middle == nil and refresh_tail == "refresh-tail",
    "Refresh must preserve all base return values")
assert(widget.mam_forge_preview.quantity.string == "999+",
    "large stacks must follow the vanilla 999+ display cap")
assert(widget.mam_forge_preview.quantity.size == 36,
    "999+ must use the vanilla compact number size")

current_plan = { phase = "harvest", product = "iron_ingot", count = 2 }
forge.listeners.mamplandirty()
assert(widget.mam_forge_preview.details.string == "Ready to collect",
    "server plan updates must refresh the forge phase")

current_plan = {
    phase = "ambiguous",
    state = "ambiguous",
    possibilities = { "copper_ingot", "iron_ingot" },
}
widget:Refresh()
assert(widget.mam_forge_preview.name.string == "Possible results",
    "ambiguous forecasts must be labelled as possibilities")
assert(widget.mam_forge_preview.details.string == "Copper Ingot / Iron Ingot",
    "all visible ambiguous outcomes must be listed")
assert(not widget.mam_forge_preview.icon.visible,
    "ambiguous forecasts must not visually privilege the first candidate")

current_plan = {
    phase = "ready",
    state = "ready",
    ambiguous = true,
    product = "copper_ingot",
    count = 3,
    outcomes = {
        { product = "copper_ingot", count = 3 },
        { product = "iron_ingot", count = 2 },
    },
}
widget:Refresh()
assert(widget.mam_forge_preview.name.string == "Possible results",
    "weighted alternatives must not be labelled as a selected product")
assert(widget.mam_forge_preview.quantity.string == "",
    "ambiguous alternatives must not show one outcome's quantity as certain")
assert(widget.mam_forge_preview.details.string == "3 x Copper Ingot / 2 x Iron Ingot",
    "ambiguous alternatives must show each candidate quantity")
assert(not widget.mam_forge_preview.icon.visible,
    "ambiguous weighted forecasts must not visually privilege one outcome")

current_plan = { phase = "invalid", state = "invalid" }
widget:Refresh()
assert(widget.mam_forge_preview.name.string == "No valid result",
    "invalid mixtures must be explained")
assert(not widget.mam_forge_preview.icon.visible,
    "invalid mixtures must not leave a stale product image")

local panel = widget.mam_forge_preview
local listener = forge.listeners.mamplandirty
widget:Close()
assert(panel.killed, "preview widgets must be destroyed when the container closes")
assert(forge.listeners.mamplandirty == nil, "server-plan listener must be removed on close")
assert(listener ~= nil, "server-plan listener must have been registered")

local chest_widget = setmetatable({ children = {} }, ContainerWidget)
chest_widget:Open(make_container("treasurechest"))
assert(chest_widget.mam_forge_preview == nil, "non-forge containers must not receive the preview")
assert(chest_widget.scale == 1, "non-forge containers must retain vanilla scale")
chest_widget:Close()

print("forge visual preview: 24 checks passed")
