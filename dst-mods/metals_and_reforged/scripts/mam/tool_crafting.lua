local G = GLOBAL or _G
local Config = require("mam/config")
local M = {}

local requirements = {
    boards = "axe",
    woodie_boards = "axe",
    boards_bunch = "axe",
    cutstone = "chisel",
    cutstone_bunch = "chisel",
}

local function requirement(recipe)
    if type(recipe) == "string" then recipe = G.GetValidRecipe(recipe) end
    if recipe == nil then return nil end
    local kind = requirements[recipe.name]
    if kind ~= nil and Config.on("mam_" .. kind .. "_crafting")
        and recipe.product == (kind == "axe" and "boards" or "cutstone") then
        return kind
    end
end

local function valid_tool(item, kind, server, owner)
    if item == nil or not item:IsValid() or item:HasTag("usesdepleted")
        or item:HasTag("broken") then
        return false
    end
    if kind == "chisel" then
        if item.prefab ~= "mam_stone_chisel" or not item:HasTag("mam_stone_chisel") then
            return false
        end
    elseif not item:HasTag("tool") or not item:HasTag("CHOP_tool") then
        return false
    end
    if not server then return true end

    local inventoryitem = item.components.inventoryitem
    if inventoryitem == nil or inventoryitem.owner ~= owner then return false end
    local uses = item.components.finiteuses
    if uses ~= nil and uses:GetUses() <= 0 then return false end
    if kind == "chisel" then return true end
    local tool = item.components.tool
    return tool ~= nil and tool:CanDoAction(G.ACTIONS.CHOP)
        and tool:GetEffectiveness(G.ACTIONS.CHOP) > 0
end

function M.HasTool(inst, kind, server)
    local inventory
    if server then
        inventory = inst.components.inventory
    else
        inventory = inst.replica.inventory
    end
    if inventory == nil then return false end
    local function contains(items, owner)
        for _, item in pairs(items) do
            if valid_tool(item, kind, server, owner) then return true end
        end
        return false
    end
    if contains(server and inventory.itemslots or inventory:GetItems(), inst)
        or contains(server and inventory.equipslots or inventory:GetEquips(), inst)
        or valid_tool(inventory:GetActiveItem(), kind, server, inst) then
        return true
    end
    local overflow = inventory:GetOverflowContainer()
    if overflow == nil then return false end
    if server then
        return not overflow.readonlycontainer and contains(overflow.slots, overflow.inst)
    end
    return not overflow:IsReadOnlyContainer() and contains(overflow:GetItems(), overflow.inst)
end

function M.CanCraft(builder, recipe, server)
    local kind = requirement(recipe)
    if kind == nil or (server and builder.freebuildmode)
        or (not server and builder:IsFreeBuildMode()) then
        return true
    end
    if M.HasTool(builder.inst, kind, server) then return true end
    return false, kind == "axe" and "MAM_NEEDS_AXE" or "MAM_NEEDS_CHISEL"
end

function M.WrapBuilder(builder, server)
    if builder._mam_tool_crafting then return end
    builder._mam_tool_crafting = true
    local old_has = builder.HasIngredients
    builder.HasIngredients = function(self, recipe, ...)
        local allowed, reason = M.CanCraft(self, recipe, server)
        if not allowed then return false, reason end
        return old_has(self, recipe, ...)
    end
    if server then
        local old_build = builder.DoBuild
        builder.DoBuild = function(self, recipe, ...)
            local allowed, reason = M.CanCraft(self, recipe, true)
            if not allowed then return false, reason end
            return old_build(self, recipe, ...)
        end
    else
        local old_buffered = builder.IsBuildBuffered
        builder.IsBuildBuffered = function(self, recipe, ...)
            if not M.CanCraft(self, recipe, false) then return false end
            return old_buffered(self, recipe, ...)
        end
    end
end

function M.WrapCraftingHUD(hud)
    if hud._mam_tool_crafting or not (Config.on("mam_axe_crafting") or Config.on("mam_chisel_crafting")) then return end
    hud._mam_tool_crafting = true
    local old_update = hud.OnUpdate
    local remaining, previous_axe, previous_chisel = 0
    hud.OnUpdate = function(self, dt, ...)
        remaining = remaining - dt
        if remaining <= 0 then
            remaining = 0.25
            -- Break/repair tags can change without an inventory event refreshing the menu.
            local axe = Config.on("mam_axe_crafting") and M.HasTool(self.owner, "axe", false)
            local chisel = Config.on("mam_chisel_crafting") and M.HasTool(self.owner, "chisel", false)
            if axe ~= previous_axe or chisel ~= previous_chisel then
                previous_axe, previous_chisel = axe, chisel
                self:UpdateRecipes()
            end
        end
        return old_update(self, dt, ...)
    end
end

function M.ApplyBoardRecipe(recipe)
    -- Only the shared vanilla recipe receives MAM's description. Its native
    -- ingredients, station, builder tags and Woodie forwarding are gameplay
    -- contracts: the axe gate must not rewrite Woodie's skill-tree recipe.
    if not Config.on("mam_axe_crafting") or recipe.name ~= "boards"
        or recipe.product ~= "boards" then
        return
    end
    if recipe.description == nil or recipe.description == "boards" then
        recipe.description = "mam_axe_boards"
    end
end

function M.ApplyStoneRecipe(recipe)
    if Config.on("mam_chisel_crafting") and recipe.product == "cutstone"
        and (recipe.description == nil or recipe.description == "cutstone") then
        recipe.description = "mam_chisel_cutstone"
    end
end

return M
