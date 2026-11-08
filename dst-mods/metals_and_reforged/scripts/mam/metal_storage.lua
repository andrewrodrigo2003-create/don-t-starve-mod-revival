-- Shared filter factory for the dedicated metal storage chest.
-- Kept separate so the actual smelter predicate and chest acceptance policy
-- can be tested together without booting the full DST mod loader.

local MAMMetalStorage = {}

function MAMMetalStorage.MakeItemTestFn(is_smelter_ingredient)
    assert(type(is_smelter_ingredient) == "function",
        "MakeItemTestFn requires the smelter ingredient predicate")

    return function(container, item, slot)
        local prefab = item ~= nil and item.prefab or nil
        return type(prefab) == "string" and is_smelter_ingredient(prefab) == true
    end
end

return MAMMetalStorage
