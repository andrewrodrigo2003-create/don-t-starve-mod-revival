-- Shared filter factory for the dedicated metal storage chest.
-- Accepts both inputs to the smelter and registered metal outputs/products.
-- This keeps storage aligned with the actual metallurgy registry rather than
-- maintaining a second, incomplete allowlist.

local MAMMetalStorage = {}

function MAMMetalStorage.MakeItemTestFn(is_smelter_ingredient, smelter_products)
    assert(type(is_smelter_ingredient) == "function",
        "MakeItemTestFn requires the smelter ingredient predicate")
    assert(type(smelter_products) == "table",
        "MakeItemTestFn requires the smelter product registry")

    return function(container, item, slot)
        local prefab = item ~= nil and item.prefab or nil
        if type(prefab) ~= "string" then
            return false
        end

        return is_smelter_ingredient(prefab) == true
            or smelter_products[prefab] ~= nil
    end
end

return MAMMetalStorage
