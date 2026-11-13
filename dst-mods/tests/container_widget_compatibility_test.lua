-- Global container widgetsetup wrapper compatibility for MAM.
-- Executes the real MAM modded_cookers.lua against isolated collaborators.
-- L2/L3 contract only; no real DST UI/renderer is present.
local passed, failed = 0, 0
local function check(name, condition)
    if condition then
        passed = passed + 1
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name)
    end
end

local original_calls = 0
local containers = {
    MAXITEMSLOTS = 1,
    widgetsetup = function(container, prefab, data, ...)
        original_calls = original_calls + 1
        container.original_prefab = prefab
        container.original_data = data
        container.original_extra = { ... }
        return "vanilla-result", prefab, data, ...
    end,
}
local forecast = {
    button_text = function() return "Smelt" end,
    can_start = function() return true end,
}
local config = { on = function(_, key) return key == "mam_batch" end }
local container_settings = {
    accepts_stacks = function(inst, default)
        if inst.server_accepts_stacks ~= nil then return inst.server_accepts_stacks end
        return default
    end,
}
local smelting = { IsSmelterIngredient = function() return true end }

GLOBAL = {
    RPC = { DoWidgetButtonAction = 1 },
    TUNING = {},
    ACTIONS = { SMELT = { code = 7, mod_name = "MetalsAndMore" } },
    Vector3 = function(x, y, z) return { x = x, y = y, z = z } end,
    BufferedAction = function() return { Do = function() end } end,
    SendRPCToServer = function() end,
    require = function(name)
        if name == "smelting" then return smelting end
        if name == "containers" then return containers end
        if name == "mam/config" then return config end
        if name == "mam/forecast" then return forecast end
        if name == "mam/container_settings" then return container_settings end
        error("unexpected require: " .. tostring(name))
    end,
}
dofile("dst-mods/metals_and_reforged/initialise/modded_cookers.lua")

local chest = { inst = { prefab = "treasurechest" } }
local a, b, c, d = containers.widgetsetup(chest, "treasurechest", nil, "extra", 42)
check("non-smelter container delegates to previous widgetsetup",
    original_calls == 1 and chest.original_prefab == "treasurechest")
check("non-smelter wrapper preserves previous return values and varargs",
    a == "vanilla-result" and b == "treasurechest" and c == nil
        and d == "extra" and chest.original_extra[2] == 42)

local custom_data = { custom = true }
local data_container = { inst = { prefab = "smelter" } }
local x, y, z, extra = containers.widgetsetup(data_container, "smelter", custom_data, "forwarded")
check("smelter call with custom data delegates instead of replacing the payload",
    original_calls == 2 and data_container.original_data == custom_data
        and x == "vanilla-result" and y == "smelter" and z == custom_data
        and extra == "forwarded")

local smelter = {
    inst = { prefab = "smelter", server_accepts_stacks = false },
    SetNumSlots = function(self, count) self.numslots = count end,
}
containers.widgetsetup(smelter, "smelter", nil)
check("MAM smelter path installs the custom widget without calling the old setup",
    original_calls == 2 and smelter.widget ~= nil and smelter.widget.buttoninfo ~= nil)
check("MAM smelter path sets slot count from widget positions",
    smelter.numslots == 4 and containers.MAXITEMSLOTS >= 4)
check("server-published container setting can override local batch default",
    smelter.acceptsstacks == false)
check("MAM widget retains forecast validation and ingredient filter",
    smelter.widget.buttoninfo.validfn(smelter.inst) == true
        and smelter.itemtestfn(smelter, { prefab = "iron_ore" }, 1) == true)

local report = string.format("Container widget compatibility: %d passed, %d failed", passed, failed)
print(report)
if failed > 0 then error(report) end
