local M = {}
local unpack = unpack

local function pack(...)
    return { n = select("#", ...), ... }
end

function M.WithDamageOverride(combat, override, callback, ...)
    assert(type(combat) == "table", "combat component required")
    assert(type(callback) == "function", "callback required")

    local previous = combat.damage_override
    combat.damage_override = override
    local results = pack(pcall(callback, combat, ...))
    combat.damage_override = previous

    if not results[1] then
        error(results[2], 0)
    end
    return unpack(results, 2, results.n)
end

function M.AreaDamageMultiplier(area_percent, additive, multiplicative)
    return (area_percent or 1) * (additive or 1) * (multiplicative or 1)
end

function M.ApplyAltDamage(current_damage, base_damage, damage_bonus, override_damage)
    local base = tonumber(base_damage) or 0
    local bonus = tonumber(damage_bonus) or 0
    local override = tonumber(override_damage)
    if override == nil then
        override = base
    end

    if base == 0 then
        return override + bonus
    end
    return ((tonumber(current_damage) or 0) - bonus) / base * override + bonus
end

return M
