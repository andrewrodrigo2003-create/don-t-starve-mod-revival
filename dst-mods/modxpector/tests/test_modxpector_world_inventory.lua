local root = os.getenv("DST_RUNTIME_ROOT") or "."
local module_path = root .. "/dst-mods/modxpector/scripts/modxpector/world_inventory.lua"
local module_chunk = assert(loadfile(module_path))
local restricted_env = setmetatable({
    type = type,
    tostring = tostring,
    tonumber = tonumber,
    ipairs = ipairs,
    pairs = pairs,
    select = select,
    string = string,
    table = table,
    os = os,
}, {
    __index = function(_, name)
        if name == "pcall" then return nil end
        return _G[name]
    end,
})
setfenv(module_chunk, restricted_env)
local inventory = module_chunk()

local infos = {
    ["workshop-100"] = {
        name = "Alpha Mod", version = "1.2", api_version = 10,
        all_clients_require_mod = true,
    },
    ["workshop-200"] = {
        name = "Client UI", version = "2.0", client_only_mod = true,
    },
    ["workshop-300"] = {
        name = "Server Utility", version = "3.0", server_only_mod = true,
    },
    ["workshop-400"] = { name = "Disabled Mod", version = "4.0" },
}
local enabled = {
    ["workshop-100"] = true,
    ["workshop-200"] = true,
    ["workshop-300"] = true,
}
local dependencies = {
    ["workshop-100"] = { "workshop-300", "workshop-400", "workshop-999" },
}
local index = {
    GetModNames = function()
        return { "workshop-100", "workshop-200", "workshop-300", "workshop-400", "workshop-100" }
    end,
    -- These are classification lists, and intentionally include disabled mods.
    GetServerModNames = function()
        return { "workshop-100", "workshop-300", "workshop-400" }
    end,
    GetClientModNames = function() return { "workshop-200" } end,
    IsModEnabledAny = function(_, id) return enabled[id] == true end,
    GetModsToLoad = function(_, usecached)
        assert(usecached == true, "scanner must use cached candidates only")
        return { "workshop-100", "workshop-200", "workshop-300" }
    end,
    GetModInfo = function(_, id) return infos[id] end,
    GetModDependencies = function(_, id, recursive)
        assert(recursive == false)
        return dependencies[id] or {}
    end,
    DoesModExistAnyVersion = function(_, id)
        return id == "workshop-100" or id == "workshop-200" or id == "workshop-300" or id == "workshop-400"
    end,
}
local globals = {
    pcall = pcall,
    DevToolsAPI = { GetAPIVersion = function() return 0.1 end },
    KnownModIndex = index,
    ModManager = {
        enabledmods = { "workshop-100" },
        failedmods = { { name = "workshop-300", error = "modmain.lua: failed to initialize" } },
    },
    Prefabs = { grass = true, skeletonservant = true, modded_prefab = true },
    AllRecipes = { spear = {}, modded_recipe = {} },
    ThePlayer = { components = { health = {}, inventory = {}, modded_component = {} } },
    TheWorld = { prefab = "forest", ismastersim = true },
    TheNet = {
        IsDedicated = function() return false end,
        GetIsServer = function() return true end,
    },
}

local result = inventory.Collect(globals)
assert(result.schema == "modxpector/world-inventory/v2")
assert(result.counts.known == 4)
assert(result.counts.enabled == 3)
assert(result.counts.load_candidates == 3)
assert(result.counts.loaded == 1)
assert(result.counts.failed == 1)
assert(result.counts.server_enabled == 2)
assert(result.counts.client_enabled == 2)
assert(result.counts.server_classified == 3)
assert(result.counts.client_classified == 1)
assert(result.capabilities.load_candidates and result.capabilities.loaded_mod_list)
assert(result.world.prefab == "forest" and result.world.is_master_sim)
assert(result.world.is_dedicated == false and result.world.is_server == true)
assert(result.capabilities.prefab_registry and result.capabilities.recipe_registry)
assert(result.capabilities.player_component_list)
assert(result.counts.prefabs == 3 and result.counts.recipes == 2 and result.counts.player_components == 3)
assert(result.registry.prefabs.names[1] == "grass" and result.registry.prefabs.names[2] == "modded_prefab")
assert(result.registry.recipes.names[1] == "modded_recipe" and result.registry.recipes.names[2] == "spear")
assert(result.registry.player_components.names[1] == "health")
assert(result.community_apis.dev_tools.available == true)
assert(result.community_apis.dev_tools.version_observed == true)
assert(result.community_apis.dev_tools.version == 0.1)
assert(#result.mods == 4, "disabled known mods must remain visible in the inventory")

local alpha = result.mods[1]
assert(alpha.id == "workshop-100" and alpha.workshop_id == "100" and alpha.is_workshop)
assert(alpha.enabled and alpha.load_candidate and alpha.loaded)
assert(alpha.load_state == "loaded" and alpha.server_enabled and alpha.client_enabled)
assert(alpha.dependencies_known and #alpha.dependencies == 3)
assert(#alpha.missing_dependencies == 1 and alpha.missing_dependencies[1] == "workshop-999")
assert(#alpha.disabled_dependencies == 1 and alpha.disabled_dependencies[1] == "workshop-400")
assert(#alpha.unverified_dependencies == 0)

local client = result.mods[2]
assert(client.client_only and client.server_enabled == false and client.client_enabled == true)
assert(client.server_classified == false and client.client_classified == true)
assert(client.load_state == "candidate_not_observed_loaded")

local server = result.mods[3]
assert(server.server_only and server.server_enabled == true and server.client_enabled == false)
assert(server.load_state == "failed")
assert(server.load_error == "modmain.lua: failed to initialize")

local disabled = result.mods[4]
assert(disabled.enabled == false and disabled.load_candidate == false)
assert(disabled.load_state == "disabled")
assert(disabled.server_classified == true)

local unknown = inventory.Collect({ pcall = pcall })
assert(unknown.counts.known == 0)
assert(not unknown.capabilities.known_mod_list)
assert(not unknown.capabilities.loaded_mod_list)
assert(unknown.community_apis.dev_tools.available == false)
assert(unknown.community_apis.dev_tools.version_observed == false)
assert(unknown.capabilities.prefab_registry == false)
assert(unknown.capabilities.recipe_registry == false)
assert(unknown.capabilities.player_component_list == false)
assert(unknown.registry.prefabs.available == false and unknown.registry.recipes.available == false)

local broken = inventory.Collect({
    pcall = pcall,
    KnownModIndex = {
        GetModNames = function() return { "broken-mod" } end,
        IsModEnabledAny = function() error("index unavailable") end,
        GetModsToLoad = function() error("cache unavailable") end,
        GetModInfo = function() error("metadata unavailable") end,
    },
})
assert(broken.counts.known == 1)
assert(broken.mods[1].enabled == nil and broken.mods[1].load_candidate == nil)
assert(broken.mods[1].loaded == nil and broken.mods[1].load_state == "unknown")

local unverified = inventory.Collect({
    pcall = pcall,
    KnownModIndex = {
        GetModNames = function() return { "workshop-owner" } end,
        IsModEnabledAny = function() return true end,
        GetModsToLoad = function() return { "workshop-owner" } end,
        GetModInfo = function() return { name = "Owner" } end,
        GetModDependencies = function() return { "workshop-not-indexed" } end,
    },
})
assert(#unverified.mods[1].missing_dependencies == 0)
assert(#unverified.mods[1].unverified_dependencies == 1)
assert(unverified.mods[1].unverified_dependencies[1] == "workshop-not-indexed")

print("MODXPECTOR_WORLD_INVENTORY_V2_OK")
